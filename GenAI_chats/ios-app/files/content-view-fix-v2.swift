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