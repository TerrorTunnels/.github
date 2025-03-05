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
    private let baseURL = "https://endpoint-of-your-aws-api-gateway-service.com"
    private let apiKey: String
    private let session: URLSession
    
    init(apiKey: String, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }
    
    // Control VPN state (start/stop)
    func controlVPN(action: VPNAction) async throws {
        guard let url = URL(string: "\(baseURL)/vpn") else {
            throw VPNError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        
        // Create request body
        let body = ["action": action.rawValue]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        do {
            let (_, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw VPNError.invalidResponse
            }
        } catch let error as VPNError {
            throw error
        } catch {
            throw VPNError.networkError(error)
        }
    }
    
    // Get VPN status
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
