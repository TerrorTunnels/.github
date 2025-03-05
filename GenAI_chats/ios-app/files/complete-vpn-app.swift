// VPNControlApp.swift
import SwiftUI

@main
struct VPNControlApp: App {
    @StateObject private var settings = AppSettings()
    
    var body: some Scene {
        WindowGroup {
            if settings.apiKey.isEmpty {
                NavigationStack {
                    SettingsView()
                        .environmentObject(settings)
                }
            } else {
                NavigationStack {
                    ContentView()
                        .environmentObject(settings)
                }
            }
        }
    }
}

// AppSettings.swift
import Foundation

@MainActor
class AppSettings: ObservableObject {
    @Published var apiKey: String {
        didSet {
            UserDefaults.standard.set(apiKey, forKey: "vpnApiKey")
        }
    }
    
    init() {
        self.apiKey = UserDefaults.standard.string(forKey: "vpnApiKey") ?? ""
    }
}

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
import Foundation

struct StatusInfo: Codable {
    let state: VPNState
    let instanceId: String?
    let lastUpdated: Date
    let message: String
}

// VPNApiClient.swift
import Foundation

enum VPNAction: String {
    case start
    case stop
}

enum VPNError: Error {
    case invalidURL
    case networkError(Error)
    case invalidResponse
    case decodingError
}

class VPNApiClient {
    private let baseURL = "https://toggle-vpn.robotterror.com"
    private let apiKey: String
    private let session: URLSession
    
    init(apiKey: String, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }
    
    func controlVPN(action: VPNAction) async throws -> [String: Any] {
        guard let url = URL(string: "\(baseURL)/vpn") else {
            throw VPNError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        
        let body = ["action": action.rawValue]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw VPNError.invalidResponse
            }
            
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw VPNError.decodingError
            }
            
            return json
        } catch let error as VPNError {
            throw error
        } catch {
            throw VPNError.networkError(error)
        }
    }
    
    func getStatus() async throws -> [String: Any] {
        guard let url = URL(string: "\(baseURL)/vpn/status") else {
            throw VPNError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw VPNError.invalidResponse
            }
            
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw VPNError.decodingError
            }
            
            return json
        } catch let error as VPNError {
            throw error
        } catch {
            throw VPNError.networkError(error)
        }
    }
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
    private var vpnClient: VPNApiClient
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

// SettingsView.swift
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settings: AppSettings
    @State private var apiKey: String = ""
    @Environment(\.dismiss) private var dismiss
    @State private var showAlert = false
    
    var body: some View {
        List {
            Section(header: Text("API Configuration")) {
                SecureField("API Key", text: $apiKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            
            Section {
                Button(action: {
                    if !apiKey.isEmpty {
                        settings.apiKey = apiKey
                        dismiss()
                    } else {
                        showAlert = true
                    }
                }) {
                    Text("Save")
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Invalid Input", isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Please enter a valid API key")
        }
        .onAppear {
            apiKey = settings.apiKey
        }
    }
}

// ContentView.swift
import SwiftUI

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