import Foundation

// MARK: - DTO

//struct LineCheckDto: Codable, Identifiable {
//    let id: String
//
//    // add other fields as needed later
//    // let userId: String?
//    // let username: String?
//    // let stations: [LineCheckStationDto]
//}

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

        try validate(response)

        return try JSONDecoder().decode(LineCheckDto.self, from: data)
    }

    // ------------------------------------------------
    // SAVE ✅ (Kotlin equivalent)
    // ------------------------------------------------
    static func saveLineCheck(
        _ lineCheck: LineCheckDto
    ) async throws -> Bool {

        guard let url = URL(
            string: "\(Config.baseURL)\(endpoint)/save"
        ) else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = try JSONEncoder().encode(lineCheck)

        // Debug log (same as Android Log.d)
        if let jsonString = String(data: body, encoding: .utf8) {
            print("📤 Sending payload:", jsonString)
        }

        request.httpBody = body

        let (_, response) = try await URLSession.shared.data(for: request)

        try validate(response)

        print("✅ Line check saved")

        return true
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
