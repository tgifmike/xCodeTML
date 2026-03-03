import Foundation

struct StationApi {
    
    static func getStationsByLocation(locationId: String) async throws -> [Station] {
        
        guard let url = URL(string: "\(Config.baseURL)/stations/by-location/\(locationId)") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        guard http.statusCode == 200 else {
            return []
        }
        
        let stations = try JSONDecoder().decode([Station].self, from: data)
        return stations.sorted { ($0.sortOrder ?? 0) < ($1.sortOrder ?? 0) }
    }
}
