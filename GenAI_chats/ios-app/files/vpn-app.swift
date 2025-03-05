// VPNApp.swift
import SwiftUI

@main 
struct VPNApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

// ContentView.swift
import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = VPNViewModel()
    
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
            .onAppear {
                Task {
                    await viewModel.checkStatus()
                }
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
    
    private let vpnClient: VPNApiClient
    
    init() {
        // Initialize with your API key
        self.vpnClient = VPNApiClient(apiKey: "YOUR-API-KEY-HERE")
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
            // Assuming the API returns a "status" field with "running" or "stopped"
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
