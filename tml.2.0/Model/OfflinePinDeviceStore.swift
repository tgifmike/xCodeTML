import Combine
import CryptoKit
import Foundation
import UIKit

@MainActor
final class OfflinePinDeviceStore: ObservableObject {
    static let shared = OfflinePinDeviceStore()

    @Published private(set) var enrollments: [OfflinePinDeviceEnrollment] = []
    @Published private(set) var verifierBundles: [OfflinePinVerifierBundle] = []
    @Published private(set) var pendingEvents: [OfflinePinEvent] = []

    private let enrollmentStorageKey = "offlinePinDeviceEnrollments"
    private let bundleStorageKey = "offlinePinVerifierBundles"
    private let eventStorageKey = "offlinePinEvents"
    private let privateKeyStorageKey = "offlinePinDevicePrivateKeyRaw"
    private let nextSequenceStorageKey = "offlinePinEventNextSequence"
    private let userDefaults: UserDefaults
    private var recentPins: [String: RecentPin] = [:]

    private init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        enrollments = load([OfflinePinDeviceEnrollment].self, forKey: enrollmentStorageKey) ?? []
        verifierBundles = load([OfflinePinVerifierBundle].self, forKey: bundleStorageKey) ?? []
        pendingEvents = load([OfflinePinEvent].self, forKey: eventStorageKey) ?? []
    }

    var hasUsablePinLogin: Bool {
        defaultEnrollment != nil
    }

    var hasDeviceEnrollment: Bool {
        !enrollments.isEmpty
    }

    func existingEnrollment(accountId: String, locationId: String? = nil) -> OfflinePinDeviceEnrollment? {
        enrollments.first { $0.accountId == accountId && $0.locationId == locationId }
    }

    func bundle(accountId: String, locationId: String? = nil) -> OfflinePinVerifierBundle? {
        verifierBundles.first { $0.accountId == accountId && $0.locationId == locationId }
    }

    var defaultEnrollment: OfflinePinDeviceEnrollment? {
        enrollments.sorted { $0.enrolledAt > $1.enrolledAt }.first
    }

    func enrollOrRefresh(accountId: String, locationId: String? = nil, deviceName: String) async throws {
        let enrollment = try await enrollmentOrCreate(accountId: accountId, locationId: locationId, deviceName: deviceName)

        do {
            let bundle = try await IpadDeviceApi.shared.getPinVerifiers(
                deviceId: enrollment.deviceId,
                deviceToken: enrollment.deviceToken
            )
            upsertBundle(bundle)
        } catch {
            if isInvalidDeviceError(error) {
                removeEnrollment(deviceId: enrollment.deviceId)
            }
            throw error
        }
    }

    func revokeDeviceAccess() async throws {
        let deviceIds = Array(Set(enrollments.map(\.deviceId)))
        guard !deviceIds.isEmpty else {
            throw OfflinePinDeviceStoreError.noDeviceEnrollment
        }

        var revokedDeviceIds: [String] = []
        do {
            for deviceId in deviceIds {
                try await IpadDeviceApi.shared.revoke(deviceId: deviceId)
                revokedDeviceIds.append(deviceId)
            }
        } catch {
            revokedDeviceIds.forEach { removeEnrollment(deviceId: $0) }
            throw error
        }

        deviceIds.forEach { removeEnrollment(deviceId: $0) }
    }

    func verifyPin(_ pin: String) async throws -> AccountScopedPinLoginResult {
        guard pin.count == 4 || pin.count == 6 else {
            throw OfflinePinDeviceStoreError.invalidPinFormat
        }

        guard let enrollment = defaultEnrollment else {
            throw OfflinePinDeviceStoreError.noDeviceEnrollment
        }

        do {
            let response = try await IpadDeviceApi.shared.verifyPinOnline(
                deviceId: enrollment.deviceId,
                pin: pin
            )

            guard response.verified,
                  let userId = response.userId,
                  let userName = response.userName,
                  let accountId = response.accountId else {
                throw OfflinePinDeviceStoreError.invalidPinResponse
            }

            cacheRecentPin(
                pin,
                accountId: accountId,
                userId: userId,
                deviceId: enrollment.deviceId,
                expiresInSeconds: response.expiresInSeconds
            )

            return AccountScopedPinLoginResult(
                accountId: accountId,
                locationId: enrollment.locationId,
                userId: userId,
                userName: userName,
                actionToken: response.employeeActionToken
            )
        } catch {
            if isConnectionError(error) {
                return try verifyPinOffline(pin, enrollment: enrollment)
            }

            throw error
        }
    }

    private func verifyPinOffline(_ pin: String, enrollment: OfflinePinDeviceEnrollment) throws -> AccountScopedPinLoginResult {
        guard let bundle = bundle(accountId: enrollment.accountId, locationId: enrollment.locationId), bundle.expiresAt > Date() else {
            throw OfflinePinDeviceStoreError.expiredVerifierBundle
        }

        var matchingUsers: [OfflinePinVerifierUser] = []
        for user in bundle.users where user.pinLength == pin.count {
            if try OfflinePinVerifier.verify(pin: pin, phcString: user.offlineVerifier) {
                matchingUsers.append(user)
            }
        }

        guard matchingUsers.count == 1, let user = matchingUsers.first else {
            throw OfflinePinDeviceStoreError.invalidPin
        }

        let loginUser = OfflinePinLoginUser(
            accountId: bundle.accountId,
            locationId: bundle.locationId,
            generatedAt: bundle.generatedAt,
            expiresAt: bundle.expiresAt,
            bundleVersion: bundle.bundleVersion,
            user: user
        )
        enqueuePinEvent(type: .offlineSuccess, loginUser: loginUser, lineCheckId: nil, lockoutUntil: nil)

        return AccountScopedPinLoginResult(
            accountId: bundle.accountId,
            locationId: bundle.locationId,
            userId: user.userId,
            userName: user.userName,
            actionToken: nil
        )
    }

    func refreshActionToken(
        accountId: String,
        userId: String,
        locationId: String
    ) async throws -> String {
        guard let recentPin = recentPin(accountId: accountId, userId: userId),
              let enrollment = enrollments.first(where: { $0.deviceId == recentPin.deviceId }) else {
            throw OfflinePinDeviceStoreError.pinReentryRequired
        }

        let response = try await IpadDeviceApi.shared.verifyPinOnline(
            accountId: accountId,
            locationId: locationId,
            userId: userId,
            deviceId: enrollment.deviceId,
            pin: recentPin.pin
        )

        guard response.verified else {
            throw OfflinePinDeviceStoreError.invalidPin
        }

        cacheRecentPin(
            recentPin.pin,
            accountId: accountId,
            userId: userId,
            deviceId: enrollment.deviceId,
            expiresInSeconds: response.expiresInSeconds
        )

        return response.employeeActionToken
    }

    func enqueuePinEvent(
        type: OfflinePinEventType,
        loginUser: OfflinePinLoginUser,
        lineCheckId: String?,
        lockoutUntil: Date?
    ) {
        guard let enrollment = existingEnrollment(accountId: loginUser.accountId, locationId: loginUser.locationId),
              let event = makeSignedEvent(
                type: type,
                accountId: loginUser.accountId,
                locationId: loginUser.locationId,
                userId: loginUser.user.userId,
                credentialVersion: loginUser.user.credentialVersion,
                lineCheckId: lineCheckId,
                lockoutUntil: lockoutUntil,
                deviceId: enrollment.deviceId
              ) else {
            return
        }

        pendingEvents.append(event)
        save(pendingEvents, forKey: eventStorageKey)
    }

    func syncPendingEvents() async -> OfflinePinEventSyncResult {
        var accepted = 0
        var failed = 0
        var remaining: [OfflinePinEvent] = []
        var lastErrorMessage: String?

        for eventsByDevice in Dictionary(grouping: pendingEvents, by: \.deviceId) {
            guard let enrollment = enrollments.first(where: { $0.deviceId == eventsByDevice.key }) else {
                remaining.append(contentsOf: eventsByDevice.value)
                failed += eventsByDevice.value.count
                lastErrorMessage = "Offline PIN event is missing device enrollment."
                continue
            }

            do {
                let response = try await IpadDeviceApi.shared.uploadOfflinePinEvents(
                    deviceId: enrollment.deviceId,
                    deviceToken: enrollment.deviceToken,
                    events: eventsByDevice.value
                )
                accepted += response.accepted + response.duplicates
            } catch {
                failed += eventsByDevice.value.count
                remaining.append(contentsOf: eventsByDevice.value)
                lastErrorMessage = error.localizedDescription
            }
        }

        pendingEvents = remaining
        save(pendingEvents, forKey: eventStorageKey)

        return OfflinePinEventSyncResult(
            accepted: accepted,
            failed: failed,
            lastErrorMessage: lastErrorMessage
        )
    }

    private func cacheRecentPin(
        _ pin: String,
        accountId: String,
        userId: String,
        deviceId: String,
        expiresInSeconds: Int
    ) {
        let key = recentPinKey(accountId: accountId, userId: userId)
        recentPins[key] = RecentPin(
            pin: pin,
            deviceId: deviceId,
            expiresAt: Date().addingTimeInterval(TimeInterval(expiresInSeconds))
        )
    }

    private func recentPin(accountId: String, userId: String) -> RecentPin? {
        let key = recentPinKey(accountId: accountId, userId: userId)
        guard let recentPin = recentPins[key], recentPin.expiresAt > Date() else {
            recentPins.removeValue(forKey: key)
            return nil
        }

        return recentPin
    }

    private func recentPinKey(accountId: String, userId: String) -> String {
        "\(accountId):\(userId)"
    }

    private func enrollmentOrCreate(accountId: String, locationId: String?, deviceName: String) async throws -> OfflinePinDeviceEnrollment {
        if let enrollment = existingEnrollment(accountId: accountId, locationId: locationId) {
            return enrollment
        }

        let key = try signingPrivateKey()
        let publicKey = x509EncodedEd25519PublicKey(fromRawPublicKey: key.publicKey.rawRepresentation)
        let response = try await IpadDeviceApi.shared.enroll(
            accountId: accountId,
            locationId: locationId,
            deviceName: deviceName,
            devicePublicKey: publicKey.base64EncodedString()
        )

        let enrollment = OfflinePinDeviceEnrollment(
            accountId: accountId,
            locationId: locationId,
            deviceId: response.deviceId,
            deviceToken: response.deviceToken,
            enrolledAt: Date()
        )

        enrollments.append(enrollment)
        save(enrollments, forKey: enrollmentStorageKey)
        return enrollment
    }

    private func makeSignedEvent(
        type: OfflinePinEventType,
        accountId: String,
        locationId: String?,
        userId: String,
        credentialVersion: Int,
        lineCheckId: String?,
        lockoutUntil: Date?,
        deviceId: String
    ) -> OfflinePinEvent? {
        do {
            let event = OfflinePinEvent(
                eventId: UUID().uuidString,
                sequenceNumber: nextSequenceNumber(),
                eventType: type.rawValue,
                accountId: accountId,
                locationId: locationId,
                userId: userId,
                credentialVersion: credentialVersion,
                occurredAt: Date(),
                lockoutUntil: lockoutUntil,
                lineCheckId: lineCheckId,
                deviceSignature: "",
                deviceId: deviceId
            )
            let signature = try signingPrivateKey().signature(for: event.canonicalPayload.data(using: .utf8) ?? Data())
            return event.withSignature(signature.base64EncodedString())
        } catch {
            return nil
        }
    }

    private func signingPrivateKey() throws -> Curve25519.Signing.PrivateKey {
        if let raw = userDefaults.data(forKey: privateKeyStorageKey) {
            return try Curve25519.Signing.PrivateKey(rawRepresentation: raw)
        }

        let key = Curve25519.Signing.PrivateKey()
        userDefaults.set(key.rawRepresentation, forKey: privateKeyStorageKey)
        return key
    }

    private func x509EncodedEd25519PublicKey(fromRawPublicKey rawPublicKey: Data) -> Data {
        var data = Data([0x30, 0x2a, 0x30, 0x05, 0x06, 0x03, 0x2b, 0x65, 0x70, 0x03, 0x21, 0x00])
        data.append(rawPublicKey)
        return data
    }

    private func nextSequenceNumber() -> Int {
        let next = userDefaults.integer(forKey: nextSequenceStorageKey) + 1
        userDefaults.set(next, forKey: nextSequenceStorageKey)
        return next
    }

    private func upsertBundle(_ bundle: OfflinePinVerifierBundle) {
        if let index = verifierBundles.firstIndex(where: {
            $0.accountId == bundle.accountId && $0.locationId == bundle.locationId
        }) {
            verifierBundles[index] = bundle
        } else {
            verifierBundles.append(bundle)
        }

        save(verifierBundles, forKey: bundleStorageKey)
    }

    private func removeEnrollment(deviceId: String) {
        let removedEnrollments = enrollments.filter { $0.deviceId == deviceId }
        let removedAccountIds = Set(removedEnrollments.map(\.accountId))

        enrollments.removeAll { $0.deviceId == deviceId }
        verifierBundles.removeAll { removedAccountIds.contains($0.accountId) }
        pendingEvents.removeAll { $0.deviceId == deviceId }
        recentPins.removeAll()

        save(enrollments, forKey: enrollmentStorageKey)
        save(verifierBundles, forKey: bundleStorageKey)
        save(pendingEvents, forKey: eventStorageKey)
    }

    private func isInvalidDeviceError(_ error: Error) -> Bool {
        if case APIError.unauthorized(let message) = error {
            return message == nil
            || message == "INVALID_DEVICE"
            || message?.localizedCaseInsensitiveContains("device") == true
        }

        return false
    }

    private func isConnectionError(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == NSURLErrorDomain
        && [NSURLErrorNotConnectedToInternet, NSURLErrorCannotConnectToHost, NSURLErrorNetworkConnectionLost, NSURLErrorTimedOut].contains(nsError.code)
    }

    private func load<T: Decodable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = userDefaults.data(forKey: key) else { return nil }

        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            userDefaults.removeObject(forKey: key)
            return nil
        }
    }

    private func save<T: Encodable>(_ value: T, forKey key: String) {
        do {
            let data = try JSONEncoder().encode(value)
            userDefaults.set(data, forKey: key)
        } catch {
            // PIN offline cache failures should not interrupt online use.
        }
    }
}

struct OfflinePinDeviceEnrollment: Codable {
    let accountId: String
    let locationId: String?
    let deviceId: String
    let deviceToken: String
    let enrolledAt: Date
}

struct OfflinePinLoginUser: Identifiable, Hashable {
    let accountId: String
    let locationId: String?
    let generatedAt: Date
    let expiresAt: Date
    let bundleVersion: Int
    let user: OfflinePinVerifierUser

    var id: String { "\(accountId)-\(locationId ?? "account")-\(user.userId)" }
}

struct AccountScopedPinLoginResult {
    let accountId: String
    let locationId: String?
    let userId: String
    let userName: String
    let actionToken: String?
}

private struct RecentPin {
    let pin: String
    let deviceId: String
    let expiresAt: Date
}

struct OfflinePinEvent: Codable {
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
    let deviceId: String

    var canonicalPayload: String {
        [
            eventId,
            String(sequenceNumber),
            eventType,
            accountId,
            locationId ?? "",
            userId,
            String(credentialVersion),
            ISO8601DateFormatter.javaInstant.string(from: occurredAt),
            lockoutUntil.map { ISO8601DateFormatter.javaInstant.string(from: $0) } ?? "",
            lineCheckId ?? ""
        ].joined(separator: "|")
    }

    func withSignature(_ signature: String) -> OfflinePinEvent {
        OfflinePinEvent(
            eventId: eventId,
            sequenceNumber: sequenceNumber,
            eventType: eventType,
            accountId: accountId,
            locationId: locationId,
            userId: userId,
            credentialVersion: credentialVersion,
            occurredAt: occurredAt,
            lockoutUntil: lockoutUntil,
            lineCheckId: lineCheckId,
            deviceSignature: signature,
            deviceId: deviceId
        )
    }

    enum CodingKeys: String, CodingKey {
        case eventId
        case sequenceNumber
        case eventType
        case accountId
        case locationId
        case userId
        case credentialVersion
        case occurredAt
        case lockoutUntil
        case lineCheckId
        case deviceSignature
        case deviceId
    }

    init(
        eventId: String,
        sequenceNumber: Int,
        eventType: String,
        accountId: String,
        locationId: String?,
        userId: String,
        credentialVersion: Int,
        occurredAt: Date,
        lockoutUntil: Date?,
        lineCheckId: String?,
        deviceSignature: String,
        deviceId: String
    ) {
        self.eventId = eventId
        self.sequenceNumber = sequenceNumber
        self.eventType = eventType
        self.accountId = accountId
        self.locationId = locationId
        self.userId = userId
        self.credentialVersion = credentialVersion
        self.occurredAt = occurredAt
        self.lockoutUntil = lockoutUntil
        self.lineCheckId = lineCheckId
        self.deviceSignature = deviceSignature
        self.deviceId = deviceId
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        eventId = try container.decode(String.self, forKey: .eventId)
        sequenceNumber = try container.decode(Int.self, forKey: .sequenceNumber)
        eventType = try container.decode(String.self, forKey: .eventType)
        accountId = try container.decode(String.self, forKey: .accountId)
        locationId = try container.decodeIfPresent(String.self, forKey: .locationId)
        userId = try container.decode(String.self, forKey: .userId)
        credentialVersion = try container.decode(Int.self, forKey: .credentialVersion)
        occurredAt = try container.decode(Date.self, forKey: .occurredAt)
        lockoutUntil = try container.decodeIfPresent(Date.self, forKey: .lockoutUntil)
        lineCheckId = try container.decodeIfPresent(String.self, forKey: .lineCheckId)
        deviceSignature = try container.decode(String.self, forKey: .deviceSignature)
        deviceId = try container.decodeIfPresent(String.self, forKey: .deviceId) ?? ""
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(eventId, forKey: .eventId)
        try container.encode(sequenceNumber, forKey: .sequenceNumber)
        try container.encode(eventType, forKey: .eventType)
        try container.encode(accountId, forKey: .accountId)
        try container.encodeIfPresent(locationId, forKey: .locationId)
        try container.encode(userId, forKey: .userId)
        try container.encode(credentialVersion, forKey: .credentialVersion)
        try container.encode(occurredAt, forKey: .occurredAt)
        try container.encodeIfPresent(lockoutUntil, forKey: .lockoutUntil)
        try container.encodeIfPresent(lineCheckId, forKey: .lineCheckId)
        try container.encode(deviceSignature, forKey: .deviceSignature)
        try container.encode(deviceId, forKey: .deviceId)
    }
}

enum OfflinePinEventType: String {
    case offlineSuccess = "PIN_OFFLINE_SUCCESS"
    case offlineFailure = "PIN_OFFLINE_FAILURE"
    case offlineLocked = "PIN_OFFLINE_LOCKED"
}

struct OfflinePinEventSyncResult {
    let accepted: Int
    let failed: Int
    let lastErrorMessage: String?
}

enum OfflinePinDeviceStoreError: LocalizedError {
    case invalidPinLength(Int)
    case invalidPinFormat
    case invalidPin
    case expiredVerifierBundle
    case noDeviceEnrollment
    case invalidPinResponse
    case pinReentryRequired

    var errorDescription: String? {
        switch self {
        case .invalidPinLength(let length):
            return "Enter a \(length)-digit PIN."
        case .invalidPinFormat:
            return "Enter a 4- or 6-digit PIN."
        case .invalidPin:
            return "PIN not recognized."
        case .expiredVerifierBundle:
            return "Offline PIN data expired. Sign in online and refresh PIN users."
        case .noDeviceEnrollment:
            return "This iPad is not enrolled for PIN login on that account."
        case .invalidPinResponse:
            return "PIN verified, but the server did not return employee details."
        case .pinReentryRequired:
            return "Enter the employee PIN again before starting this line check."
        }
    }
}

extension ISO8601DateFormatter {
    static let javaInstant: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}
