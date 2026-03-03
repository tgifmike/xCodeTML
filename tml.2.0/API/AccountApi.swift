import Foundation

class AccountApi {
    
    static let shared = AccountApi()
    
    
    func getAccountsForUser(userId: String) async -> [Account] {
        guard let url = URL(string: "\(Config.baseURL)/user-access/\(userId)/accounts") else {
            return []
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return []
            }
            
            let decoder = JSONDecoder()
            return try decoder.decode([Account].self, from: data)
            
        } catch {
            print("Account fetch error:", error)
            return []
        }
    }
}
