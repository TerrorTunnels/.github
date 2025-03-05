// VPNViewModel.swift
import Foundation
import SwiftUI

@MainActor
class VPNViewModel: ObservableObject {
    @Published var vpnState: VPNState = .stopped
    @Published var isLoading = false
    @Published var errorMessage = ""
    @Published var statusMessage = "Checking status..."
    @Published var instanceId: String?
    @Published var lastUpdated: Date?
    
    private var pollingTask: Task<Void, Never>?
    private let vpnClient: VPNApiClient
    private let statusUpdateInterval: TimeInterval = 1.0 // 1 second
    
    init() {
        self.vpnClient = VPNApiClient(apiKey: UserDefaults.standard.string(forKey: "vpnApiKey") ?? "")
        loadSavedStatus()
    }
    
    private func loadSavedStatus() {
        if let savedData = UserDefaults.standard.data(forKey: "lastKnownStatus"),
           let status = try? JSONDecoder().decode(StatusInfo.self, from: savedData) {
            vpnState = status.state
            instanceId = status.instanceId
            lastUpdated = status.lastUpdated
            statusMessage = status.message
        }
    }
    
    private func saveStatus() {
        let status = StatusInfo(
            state: vpnState,
            instanceId: instanceId,
            lastUpdated: lastUpdated ?? Date(),
            message: statusMessage
        )
        
        if let encoded = try? JSONEncoder().encode(status) {
            UserDefaults.standard.set(encoded, forKey: "lastKnownStatus")
        }
    }
    
    func updateApiKey(_ apiKey: String) {
        vpnClient = VPNApiClient(apiKey: apiKey)
    }
    
    func toggleVPN() async {
        isLoading = true
        errorMessage = ""
        
        do {
            let action: VPNAction = vpnState == .stopped ? .start : .stop
            let response = try await vpnClient.controlVPN(action: action)
            
            if let message = response["message"] as? String {
                statusMessage = message
                
                if message.contains("starting") {
                    vpnState = .starting
                } else if message.contains("stopping") {
                    vpnState = .stopping
                }
                
                if let id = message.components(separatedBy: "Instance ").last?.components(separatedBy: " is").first {
                    instanceId = id
                }
                
                lastUpdated = Date()
                saveStatus()
                startPolling()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func checkStatus() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = ""
        
        do {
            let status = try await vpnClient.getStatus()
            if let message = status["message"] as? String {
                statusMessage = message
                
                if message.contains("running") {
                    vpnState = .running
                } else if message.contains("stopped") {
                    vpnState = .stopped
                } else if message.contains("starting") {
                    vpnState = .starting
                } else if message.contains("stopping") {
                    vpnState = .stopping
                }
                
                if let id = message.components(separatedBy: "Instance ").last?.components(separatedBy: " is").first {
                    instanceId = id
                }
                
                lastUpdated = Date()
                saveStatus()
                
                if vpnState.isTransitioning {
                    startPolling()
                } else {
                    stopPolling()
                }
            }
        } catch {
            errorMessage = error.localizedDescription
            statusMessage = "Unable to determine VPN status"
        }
        
        isLoading = false
    }
    
    func forceRefresh() async {
        stopPolling()
        await checkStatus()
    }
    
    private func startPolling() {
        stopPolling()
        
        pollingTask = Task {
            while vpnState.isTransitioning {
                try? await Task.sleep(nanoseconds: UInt64(statusUpdateInterval * 1_000_000_000))
                await checkStatus()
            }
        }
    }
    
    private func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }
    
    deinit {
        Task { @MainActor in
            stopPolling()
        }
    }
}
