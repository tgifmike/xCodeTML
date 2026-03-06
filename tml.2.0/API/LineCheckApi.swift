import Foundation

// MARK: - API

final class LineCheckApi {

    private static let endpoint = "/line-checks"

    // ------------------------------------------------
    // CREATE (already working)
    // ------------------------------------------------
    static func createLineCheck(
        userId: String,
        stationIds: [String]
    ) async throws -> LineCheckDto {

        guard let url = URL(
            string: "\(Config.baseURL)\(endpoint)/create?userId=\(userId)"
        ) else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        request.httpBody = try JSONEncoder().encode(stationIds)

        let (data, response) = try await URLSession.shared.data(for: request)

        try validate(response)

        return try JSONDecoder().decode(LineCheckDto.self, from: data)
    }

    // ------------------------------------------------
    // GET BY ID  ✅ (Kotlin equivalent)
    // ------------------------------------------------
    static func getLineCheckById(
        lineCheckId: String
    ) async throws -> LineCheckDto {

        guard let url = URL(
            string: "\(Config.baseURL)\(endpoint)/\(lineCheckId)"
        ) else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        if !(200...299).contains(http.statusCode) {

            let body = String(data: data, encoding: .utf8) ?? "No body"
            
            print("❌ HTTP Status:", http.statusCode)
            print("❌ Server response:", body)

            throw NSError(
                domain: "ServerError",
                code: http.statusCode,
                userInfo: [NSLocalizedDescriptionKey: body]
            )
        }

        return try JSONDecoder().decode(LineCheckDto.self, from: data)
    }

    // ------------------------------------------------
    // SAVE ✅ (Kotlin equivalent)
    // ------------------------------------------------
    static func saveLineCheck(
        _ lineCheck: LineCheckDto
    ) async throws {

        guard let url = URL(
            string: "\(Config.baseURL)\(endpoint)/save"
        ) else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = try JSONEncoder().encode(lineCheck)

        if let json = String(data: body, encoding: .utf8) {
            print("📤 Payload:", json)
        }

        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        if !(200...299).contains(http.statusCode) {

            let serverMessage = String(data: data, encoding: .utf8) ?? "Unknown error"

            print("❌ Status:", http.statusCode)
            print("❌ Server:", serverMessage)

            throw NSError(
                domain: "ServerError",
                code: http.statusCode,
                userInfo: [NSLocalizedDescriptionKey: serverMessage]
            )
        }

        print("✅ Save successful")
    }
    // ------------------------------------------------
    // Shared response validation
    // ------------------------------------------------
    private static func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }
}
