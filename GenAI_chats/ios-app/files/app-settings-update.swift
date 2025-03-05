// AppSettings.swift
import Foundation
import SwiftUI

@MainActor
class AppSettings: ObservableObject {
    @Published private(set) var apiKey: String
    private let keychain = KeychainManager.shared
    private let apiKeyIdentifier = "vpnApiKey"
    
    init() {
        // Try to get API key from keychain, default to empty string if not found
        do {
            self.apiKey = try keychain.retrieve(for: apiKeyIdentifier)
        } catch {
            self.apiKey = ""
            print("Failed to retrieve API key from keychain: \(error)")
        }
    }
    
    func setApiKey(_ newKey: String) {
        do {
            try keychain.save(newKey, for: apiKeyIdentifier)
            self.apiKey = newKey
        } catch {
            print("Failed to save API key to keychain: \(error)")
        }
    }
    
    func clearApiKey() {
        do {
            try keychain.delete(for: apiKeyIdentifier)
            self.apiKey = ""
        } catch {
            print("Failed to delete API key from keychain: \(error)")
        }
    }
}
