// SettingsView.swift
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settings: AppSettings
    @State private var apiKey: String = ""
    @Environment(\.dismiss) private var dismiss
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var showingConfirmation = false
    
    var body: some View {
        List {
            Section(header: Text("API Configuration")) {
                SecureField("API Key", text: $apiKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            
            Section {
                Button(action: saveApiKey) {
                    Text("Save")
                        .frame(maxWidth: .infinity)
                }
                
                if !settings.apiKey.isEmpty {
                    Button(role: .destructive, action: { showingConfirmation = true }) {
                        Text("Clear API Key")
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Error", isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
        .confirmationDialog(
            "Are you sure you want to clear the API key?",
            isPresented: $showingConfirmation,
            titleVisibility: .visible
        ) {
            Button("Clear Key", role: .destructive) {
                settings.clearApiKey()
                apiKey = ""
            }
            Button("Cancel", role: .cancel) { }
        }
        .onAppear {
            apiKey = settings.apiKey
        }
    }
    
    private func saveApiKey() {
        if apiKey.isEmpty {
            alertMessage = "Please enter a valid API key"
            showAlert = true
            return
        }
        
        settings.setApiKey(apiKey)
        dismiss()
    }
}
