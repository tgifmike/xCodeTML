import Foundation

final class IpadDeviceApi {
    static let shared = IpadDeviceApi()

    private init() {}

    func enroll(
        accountId: String,
        locationId: String? = nil,
        deviceName: String,
        devicePublicKey: String
    ) async throws -> IpadEnrollmentResponse {
        try await jsonRequest(
            path: "/ipad/devices/enroll",
            method: .POST,
            body: IpadEnrollmentRequest(
                accountId: accountId,
                locationId: locationId,
                deviceName: deviceName,
                devicePublicKey: devicePublicKey
            ),
            responseType: IpadEnrollmentResponse.self
        )
    }

    func revoke(deviceId: String) async throws {
        _ = try await jsonRequest(
            path: "/ipad/devices/\(deviceId.urlPathSegmentEncoded)",
            method: .DELETE,
            body: Optional<EmptyRequest>.none,
            responseType: EmptyResponse.self
        )
    }

    func getPinVerifiers(
        deviceId: String,
        deviceToken: String
    ) async throws -> OfflinePinVerifierBundle {
        try await jsonRequest(
            path: "/ipad/devices/\(deviceId.urlPathSegmentEncoded)/pin-verifiers",
            method: .GET,
            deviceId: deviceId,
            deviceToken: deviceToken,
            body: Optional<EmptyRequest>.none,
            responseType: OfflinePinVerifierBundle.self
        )
    }

    func verifyPinOnline(
        deviceId: String,
        pin: String
    ) async throws -> PinVerificationResponse {
        try await jsonRequest(
            path: "/auth/pin/verify",
            method: .POST,
            body: DevicePinVerificationRequest(
                deviceId: deviceId,
                pin: pin
            ),
            responseType: PinVerificationResponse.self,
            useSessionAuthorization: false
        )
    }

    func verifyPinOnline(
        accountId: String,
        locationId: String? = nil,
        userId: String? = nil,
        deviceId: String,
        pin: String
    ) async throws -> PinVerificationResponse {
        try await jsonRequest(
            path: "/auth/pin/verify",
            method: .POST,
            body: PinVerificationRequest(
                accountId: accountId,
                locationId: locationId,
                userId: userId,
                deviceId: deviceId,
                pin: pin
            ),
            responseType: PinVerificationResponse.self,
            useSessionAuthorization: false
        )
    }

    func uploadOfflinePinEvents(
        deviceId: String,
        deviceToken: String,
        events: [OfflinePinEvent]
    ) async throws -> OfflinePinEventBatchResponse {
        try await jsonRequest(
            path: "/ipad/devices/\(deviceId.urlPathSegmentEncoded)/pin-events/batch",
            method: .POST,
            deviceId: deviceId,
            deviceToken: deviceToken,
            body: OfflinePinEventBatchRequest(events: events),
            responseType: OfflinePinEventBatchResponse.self
        )
    }

    private func jsonRequest<RequestBody: Encodable, ResponseBody: Decodable>(
        path: String,
        method: HTTPMethod,
        deviceId: String? = nil,
        deviceToken: String? = nil,
        body: RequestBody?,
        responseType: ResponseBody.Type,
        useSessionAuthorization: Bool = true
    ) async throws -> ResponseBody {
        guard let url = URL(string: "\(Config.baseURL)\(path)") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let deviceId, let deviceToken {
            request.setValue(deviceId, forHTTPHeaderField: "X-Device-Id")
            request.setValue("Device \(deviceToken)", forHTTPHeaderField: "Authorization")
        } else if useSessionAuthorization, let jwt = APIClient.shared.jwt {
            request.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        }

        if let body {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .custom { date, encoder in
                var container = encoder.singleValueContainer()
                try container.encode(ISO8601DateFormatter.javaInstant.string(from: date))
            }
            request.httpBody = try encoder.encode(body)
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        return try decode(data: data, response: response, responseType: responseType)
    }

    private func decode<ResponseBody: Decodable>(
        data: Data,
        response: URLResponse,
        responseType: ResponseBody.Type
    ) throws -> ResponseBody {
        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        switch http.statusCode {
        case 200...299:
            break
        case 401:
            if isPinVerificationFailure(data: data) {
                let warning = pinFailureDetails(from: data)
                throw APIError.pinFailed(warning.message, warning.nextLockoutUntil)
            }
            throw APIError.unauthorized(serverMessage(from: data))
        case 403:
            throw APIError.forbidden(serverMessage(from: data))
        case 423:
            let lockout = lockoutDetails(from: data)
            throw APIError.locked(lockout.message, lockout.lockedUntil, lockout.retryAfterSeconds)
        default:
            throw APIError.serverError(http.statusCode, serverMessage(from: data))
        }

        if data.isEmpty {
            guard ResponseBody.self == EmptyResponse.self else {
                throw APIError.invalidResponse
            }

            return EmptyResponse() as! ResponseBody
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)

            if let date = ISO8601DateFormatter.withInternetDateTimeAndFractions.date(from: value)
                ?? ISO8601DateFormatter.withInternetDateTime.date(from: value) {
                return date
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid ISO-8601 date: \(value)"
            )
        }

        return try decoder.decode(ResponseBody.self, from: data)
    }

    private func serverMessage(from data: Data) -> String? {
        guard !data.isEmpty else { return nil }

        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            for key in ["message", "error", "detail"] {
                if let message = json[key] as? String, !message.isEmpty {
                    return message
                }
            }
        }

        return String(data: data, encoding: .utf8)
    }

    private func isPinVerificationFailure(data: Data) -> Bool {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return false
        }

        let code = json["code"] as? String
            ?? json["error"] as? String
            ?? json["reason"] as? String
        return code == "PIN_VERIFICATION_FAILED"
            || code == "PIN_MISMATCH"
    }

    private func pinFailureDetails(from data: Data) -> (message: String?, nextLockoutUntil: Date?) {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return (serverMessage(from: data), nil)
        }

        let nextLockoutUntilValue = json["nextLockoutUntil"] as? String
            ?? json["nextPinLockoutUntil"] as? String
            ?? json["willLockUntil"] as? String
            ?? json["wouldLockUntil"] as? String
        return (serverMessage(from: data), parseDate(nextLockoutUntilValue))
    }

    private func lockoutDetails(from data: Data) -> (message: String?, lockedUntil: Date?, retryAfterSeconds: Int?) {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return (serverMessage(from: data), nil, nil)
        }

        let message = serverMessage(from: data)
        let lockedUntilValue = json["lockedUntil"] as? String
            ?? json["lockoutUntil"] as? String
            ?? json["pinLockedUntil"] as? String
        let retryAfterSeconds = json["retryAfterSeconds"] as? Int
            ?? json["retryAfter"] as? Int

        return (message, parseDate(lockedUntilValue), retryAfterSeconds)
    }

    private func parseDate(_ value: String?) -> Date? {
        guard let value else { return nil }
        return ISO8601DateFormatter.withInternetDateTimeAndFractions.date(from: value)
            ?? ISO8601DateFormatter.withInternetDateTime.date(from: value)
    }
}

private struct EmptyRequest: Encodable {}

struct IpadEnrollmentRequest: Encodable {
    let accountId: String
    let locationId: String?
    let deviceName: String
    let devicePublicKey: String
}

struct IpadEnrollmentResponse: Decodable {
    let deviceId: String
    let deviceToken: String
}

struct OfflinePinVerifierBundle: Codable {
    let accountId: String
    let locationId: String?
    let generatedAt: Date
    let expiresAt: Date
    let bundleVersion: Int
    let users: [OfflinePinVerifierUser]
}

struct OfflinePinVerifierUser: Identifiable, Codable, Hashable {
    let userId: String
    let userName: String
    let userImage: String?
    let pinLength: Int
    let offlineVerifier: String
    let credentialVersion: Int

    var id: String { userId }
}

struct DevicePinVerificationRequest: Encodable {
    let deviceId: String
    let pin: String
}

struct PinVerificationRequest: Encodable {
    let accountId: String
    let locationId: String?
    let userId: String?
    let deviceId: String
    let pin: String
}

struct PinVerificationResponse: Decodable {
    let verified: Bool
    let employeeActionToken: String
    let expiresInSeconds: Int
    let userId: String?
    let userName: String?
    let accountId: String?
}

struct OfflinePinEventBatchRequest: Encodable {
    let events: [OfflinePinEventUpload]

    init(events: [OfflinePinEvent]) {
        self.events = events.map { OfflinePinEventUpload(event: $0) }
    }
}

struct OfflinePinEventUpload: Encodable {
    let eventId: String
    let sequenceNumber: Int
    let eventType: String
    let accountId: String
    let locationId: String?
    let userId: String
    let credentialVersion: Int
    let occurredAt: Date
    let lockoutUntil: Date?
    let lineCheckId: String?
    let deviceSignature: String

    init(event: OfflinePinEvent) {
        eventId = event.eventId
        sequenceNumber = event.sequenceNumber
        eventType = event.eventType
        accountId = event.accountId
        locationId = event.locationId
        userId = event.userId
        credentialVersion = event.credentialVersion
        occurredAt = event.occurredAt
        lockoutUntil = event.lockoutUntil
        lineCheckId = event.lineCheckId
        deviceSignature = event.deviceSignature
    }
}

struct OfflinePinEventBatchResponse: Decodable {
    let accepted: Int
    let duplicates: Int
    let staleCredentials: Int
}

extension ISO8601DateFormatter {
    static let withInternetDateTimeAndFractions: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static let withInternetDateTime: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}
