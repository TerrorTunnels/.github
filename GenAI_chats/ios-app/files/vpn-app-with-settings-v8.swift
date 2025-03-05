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
                VStack(spacing: 20) {
                    // Status Card
                    VStack(spacing: 16) {
                        // Status Icon
                        Image(systemName: viewModel.isVPNActive ? "lock.fill" : "lock.open.fill")
                            .font(.system(size: 50))
                            .foregroundColor(viewModel.isVPNActive ? .green : .red)
                        
                        // Status Information
                        VStack(spacing: 8) {
                            // Instance Status
                            HStack {
                                Circle()
                                    .fill(viewModel.isVPNActive ? Color.green : Color.red)
                                    .frame(width: 8, height: 8)
                                Text(viewModel.isVPNActive ? "Running" : "Stopped")
                                    .font(.headline)
                                    .foregroundColor(viewModel.isVPNActive ? .green : .red)
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
                .padding(.vertical)
            }
        }
        .navigationTitle("VPN Control")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
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

// VPNViewModel.swift remains the same as before
