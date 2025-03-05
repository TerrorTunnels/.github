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

// VPNControlApp.swift
import SwiftUI

@main
struct VPNControlApp: App {
    @StateObject private var settings = AppSettings()
    
    var body: some Scene {
        WindowGroup {
            if settings.apiKey.isEmpty {
                SettingsView()
                    .environmentObject(settings)
            } else {
                ContentView()
                    .environmentObject(settings)
            }
        }
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
        NavigationView {
            Form {
                Section(header: Text("API Configuration")) {
                    SecureField("API Key", text: $apiKey)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                }
                
                Section {
                    Button("Save") {
                        if !apiKey.isEmpty {
                            settings.apiKey = apiKey
                            dismiss()
                        } else {
                            showAlert = true
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .alert("Invalid Input", isPresented: $showAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Please enter a valid API key")
            }
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
        NavigationView {
            VStack(spacing: 20) {
                // Status Card
                VStack {
                    Image(systemName: viewModel.isVPNActive ? "lock.fill" : "lock.open.fill")
                        .font(.system(size: 50))
                        .foregroundColor(viewModel.isVPNActive ? .green : .red)
                    
                    Text(viewModel.statusMessage)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(10)
                .shadow(radius: 2)
                
                // Control Button
                Button(action: {
                    Task {
                        await viewModel.toggleVPN()
                    }
                }) {
                    Text(viewModel.isVPNActive ? "Stop VPN" : "Start VPN")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(viewModel.isVPNActive ? Color.red : Color.green)
                        .cornerRadius(10)
                }
                .disabled(viewModel.isLoading)
                
                if viewModel.isLoading {
                    ProgressView()
                }
                
                if !viewModel.errorMessage.isEmpty {
                    Text(viewModel.errorMessage)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }
            }
            .padding()
            .navigationTitle("VPN Control")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gear")
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
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
}

// VPNViewModel.swift
import Foundation

@MainActor
class VPNViewModel: ObservableObject {
    @Published var isVPNActive = false
    @Published var isLoading = false
    @Published var errorMessage = ""
    @Published var statusMessage = "Checking status..."
    
    private var vpnClient: VPNApiClient
    
    init() {
        self.vpnClient = VPNApiClient(apiKey: "")
    }
    
    func updateApiKey(_ apiKey: String) {
        vpnClient = VPNApiClient(apiKey: apiKey)
    }
    
    func toggleVPN() async {
        isLoading = true
        errorMessage = ""
        
        do {
            try await vpnClient.controlVPN(action: isVPNActive ? .stop : .start)
            await checkStatus()
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func checkStatus() async {
        isLoading = true
        errorMessage = ""
        
        do {
            let status = try await vpnClient.getStatus()
            if let vpnStatus = status["status"] as? String {
                isVPNActive = vpnStatus == "running"
                statusMessage = "VPN is \(vpnStatus)"
            }
        } catch {
            errorMessage = error.localizedDescription
            statusMessage = "Unable to determine VPN status"
        }
        
        isLoading = false
    }
}
