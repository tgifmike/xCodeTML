//
//  APIClient.swift
//  tml.2.0
//
//  Created by mike on 4/28/26.
//

import Foundation

final class APIClient {

    static let shared = APIClient()

    private init() {}

    // JWT stored here once after login
    var jwt: String?

    // MARK: - Generic Request

    func request<T: Decodable>(
        _ endpoint: Endpoint,
        responseType: T.Type
    ) async throws -> T {

        guard let url = endpoint.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue

        // 🔐 AUTH AUTOMATICALLY ATTACHED
        if let jwt {
            request.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        }

        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let body = endpoint.body {
            request.httpBody = try JSONEncoder().encode(AnyEncodable(body))
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        switch http.statusCode {
        case 200...299:
            return try JSONDecoder().decode(T.self, from: data)

        case 401:
            throw APIError.unauthorized

        case 403:
            throw APIError.forbidden

        default:
            throw APIError.serverError(http.statusCode)
        }
    }
}
