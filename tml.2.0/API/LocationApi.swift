import Foundation

final class LocationApi {
    
    static let shared = LocationApi()
    
    
//    func getLocationsForAccount(accountId: String) async -> [Location] {
//        
//        guard let url = URL(string: "\(Config.baseURL)/locations/accounts/\(accountId)/locations") else {
//            return []
//        }
//        
//        var request = URLRequest(url: url)
//        request.httpMethod = "GET"
//        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
//        
//        do {
//            let (data, response) = try await URLSession.shared.data(for: request)
//            
//            guard let httpResponse = response as? HTTPURLResponse else {
//                return []
//            }
//            
//            if httpResponse.statusCode == 200 {
//                return try JSONDecoder().decode([Location].self, from: data)
//            } else if httpResponse.statusCode == 404 {
//                return []
//            } else {
//                return []
//            }
//            
//        } catch {
//            return []
//        }
//    }
    
    func getLocationsForAccount(accountId: String) async -> [Location] {
        
        guard let url = URL(string: "\(Config.baseURL)/locations/accounts/\(accountId)/locations") else {
            print("❌ Bad URL")
            return []
        }
        
        print("🌍 URL:", url.absoluteString)
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid response")
                return []
            }
            
            print("📡 Status Code:", httpResponse.statusCode)
            print("📦 Raw JSON:", String(data: data, encoding: .utf8) ?? "")
            
            if httpResponse.statusCode == 200 {
                do {
                    return try JSONDecoder().decode([Location].self, from: data)
                } catch {
                    print("❌ Decode error:", error)
                    return []
                }
            } else {
                return []
            }
            
        } catch {
            print("❌ Network error:", error)
            return []
        }
    }
    
    static func getLocationsForUser(userId: String) async throws -> [Location] {
            
            guard let url = URL(string: "\(Config.baseURL)/user-access-locations/\(userId)/locations") else {
                throw URLError(.badURL)
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let http = response as? HTTPURLResponse else {
                throw URLError(.badServerResponse)
            }
            
            if http.statusCode == 200 {
                return try JSONDecoder().decode([Location].self, from: data)
            } else if http.statusCode == 404 {
                return []
            } else {
                throw URLError(.badServerResponse)
            }
        }
}
