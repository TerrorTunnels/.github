// VPNState.swift
import Foundation
import SwiftUI

enum VPNState: String, Codable {
    case running
    case stopped
    case starting
    case stopping
    
    var displayText: String {
        switch self {
        case .running: return "Running"
        case .stopped: return "Stopped"
        case .starting: return "Starting"
        case .stopping: return "Stopping"
        }
    }
    
    var color: Color {
        switch self {
        case .running: return .green
        case .stopped: return .red
        case .starting, .stopping: return .orange
        }
    }
    
    var icon: String {
        switch self {
        case .running: return "lock.fill"
        case .stopped: return "lock.open.fill"
        case .starting: return "lock.rotation"
        case .stopping: return "lock.rotation"
        }
    }
    
    var isTransitioning: Bool {
        self == .starting || self == .stopping
    }
}

// StatusInfo.swift
struct StatusInfo: Codable {
    let state: VPNState
    let instanceId: String?
    let lastUpdated: Date
    let message: String
}

// VPNViewModel.swift
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
        stopPolling()
    }
}

// ContentView.swift updates for status refresh button and last updated time
struct ContentView: View {
    @StateObject private var viewModel = VPNViewModel()
    @EnvironmentObject var settings: AppSettings
    @State private var showingSettings = false
    
    var body: some View {
        List {
            Section {
                VStack(spacing: 16) {
                    // Status Card
                    VStack(spacing: 16) {
                        // Status Icon
                        Image(systemName: viewModel.vpnState.icon)
                            .font(.system(size: 50))
                            .foregroundColor(viewModel.vpnState.color)
                            .symbolEffect(.bounce, options: .repeating, value: viewModel.vpnState.isTransitioning)
                        
                        // Status Information
                        VStack(spacing: 8) {
                            // Instance Status
                            HStack {
                                Circle()
                                    .fill(viewModel.vpnState.color)
                                    .frame(width: 8, height: 8)
                                Text(viewModel.vpnState.displayText)
                                    .font(.headline)
                                    .foregroundColor(viewModel.vpnState.color)
                            }
                            
                            // Instance ID
                            if let instanceId = viewModel.instanceId {
                                VStack(spacing: 4) {
                                    Text("Instance ID")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                    Text(instanceId)
                                        .font(.subheadline)
                                        .monospaced()
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 8)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                            }
                            
                            // Last Updated
                            if let lastUpdated = viewModel.lastUpdated {
                                Text("Last updated: \(lastUpdated.formatted(.relative(presentation: .named)))")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(radius: 1)
                    
                    // Control Button
                    Button(action: {
                        Task {
                            await viewModel.toggleVPN()
                        }
                    }) {
                        Text(viewModel.vpnState == .stopped ? "Start VPN" : "Stop VPN")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(viewModel.vpnState == .stopped ? Color.green : Color.red)
                            .cornerRadius(10)
                    }
                    .disabled(viewModel.isLoading || viewModel.vpnState.isTransitioning)
                }
                .padding(.vertical)
            }
        }
        .navigationTitle("VPN Control")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    Task {
                        await viewModel.forceRefresh()
                    }
                }) {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(viewModel.isLoading)
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingSettings = true }) {
                    Image(systemName: "gear")
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            NavigationStack {
                SettingsView()
            }
        }
        .onAppear {
            viewModel.updateApiKey(settings.apiKey)
            Task {
                await viewModel.checkStatus()
            }
        }
        .onChange(of: settings.apiKey) { newValue in
            viewModel.updateApiKey(newValue)
        }
    }
}