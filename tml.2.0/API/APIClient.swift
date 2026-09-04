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

        return try decode(data: data, response: response, responseType: responseType)
    }

    func uploadMultipart<T: Decodable>(
        path: String,
        fileFieldName: String,
        fileName: String,
        mimeType: String,
        fileData: Data,
        fields: [String: String],
        responseType: T.Type
    ) async throws -> T {

        guard let url = URL(string: "\(Config.baseURL)\(path)") else {
            throw APIError.invalidURL
        }

        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: url)
        request.httpMethod = HTTPMethod.POST.rawValue

        if let jwt {
            request.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        }

        request.setValue(
            "multipart/form-data; boundary=\(boundary)",
            forHTTPHeaderField: "Content-Type"
        )

        request.httpBody = makeMultipartBody(
            boundary: boundary,
            fileFieldName: fileFieldName,
            fileName: fileName,
            mimeType: mimeType,
            fileData: fileData,
            fields: fields
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        return try decode(data: data, response: response, responseType: responseType)
    }

    private func decode<T: Decodable>(
        data: Data,
        response: URLResponse,
        responseType: T.Type
    ) throws -> T {

        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        switch http.statusCode {
        case 200...299:

            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            decoder.dateDecodingStrategy = .iso8601

            // ✅ HANDLE EMPTY RESPONSE (204, 200 with no body)
            if data.isEmpty {

                guard T.self == EmptyResponse.self else {
                    throw APIError.invalidResponse
                }

                return EmptyResponse() as! T
            }

            return try decoder.decode(T.self, from: data)
        case 401:
            throw APIError.unauthorized(serverMessage(from: data))

        case 403:
            throw APIError.forbidden(serverMessage(from: data))

        case 423:
            let lockout = lockoutDetails(from: data)
            throw APIError.locked(lockout.message, lockout.lockedUntil, lockout.retryAfterSeconds)

        default:
            throw APIError.serverError(http.statusCode, serverMessage(from: data))
        }
    }

    private func serverMessage(from data: Data) -> String? {
        guard !data.isEmpty else { return nil }

        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            for key in ["message", "error", "detail"] {
                if let message = json[key] as? String, !message.isEmpty {
                    return cleanedServerMessage(message)
                }
            }

            if let errors = json["errors"] as? [String], !errors.isEmpty {
                return errors.joined(separator: "\n")
            }

            if let errors = json["errors"] as? [String: Any], !errors.isEmpty {
                return errors
                    .map { "\($0.key): \($0.value)" }
                    .sorted()
                    .joined(separator: "\n")
            }
        }

        if let message = String(data: data, encoding: .utf8), !message.isEmpty {
            return cleanedServerMessage(message)
        }

        return nil
    }

    private func lockoutDetails(from data: Data) -> (message: String?, lockedUntil: Date?, retryAfterSeconds: Int?) {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return (serverMessage(from: data), nil, nil)
        }

        let message = serverMessage(from: data)
        let lockedUntilValue = json["lockedUntil"] as? String
            ?? json["lockoutUntil"] as? String
            ?? json["pinLockedUntil"] as? String
        let lockedUntil = lockedUntilValue.flatMap { ISO8601DateFormatter.withInternetDateTimeAndFractions.date(from: $0) }
            ?? lockedUntilValue.flatMap { ISO8601DateFormatter.withInternetDateTime.date(from: $0) }
        let retryAfterSeconds = json["retryAfterSeconds"] as? Int
            ?? json["retryAfter"] as? Int

        return (message, lockedUntil, retryAfterSeconds)
    }

    private func cleanedServerMessage(_ message: String) -> String {
        message
            .replacingOccurrences(of: "400 BAD_REQUEST ", with: "")
            .replacingOccurrences(of: "Bad Request: ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func makeMultipartBody(
        boundary: String,
        fileFieldName: String,
        fileName: String,
        mimeType: String,
        fileData: Data,
        fields: [String: String]
    ) -> Data {

        var body = Data()
        let lineBreak = "\r\n"

        for (name, value) in fields {
            body.appendString("--\(boundary)\(lineBreak)")
            body.appendString("Content-Disposition: form-data; name=\"\(name)\"\(lineBreak + lineBreak)")
            body.appendString("\(value)\(lineBreak)")
        }

        body.appendString("--\(boundary)\(lineBreak)")
        body.appendString("Content-Disposition: form-data; name=\"\(fileFieldName)\"; filename=\"\(fileName)\"\(lineBreak)")
        body.appendString("Content-Type: \(mimeType)\(lineBreak + lineBreak)")
        body.append(fileData)
        body.appendString(lineBreak)
        body.appendString("--\(boundary)--\(lineBreak)")

        return body
    }
}

private extension Data {
    mutating func appendString(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
