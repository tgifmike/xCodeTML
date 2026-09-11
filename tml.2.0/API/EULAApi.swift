import Foundation

struct EULAAcceptanceStatus: Codable {
    let acceptedVersion: Int?
    let accepted: Bool?

    enum CodingKeys: String, CodingKey {
        case acceptedVersion
        case eulaVersion
        case version
        case accepted
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        acceptedVersion = try container.decodeIfPresent(Int.self, forKey: .acceptedVersion)
        ?? container.decodeIfPresent(Int.self, forKey: .eulaVersion)
        ?? container.decodeIfPresent(Int.self, forKey: .version)
        accepted = try container.decodeIfPresent(Bool.self, forKey: .accepted)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(acceptedVersion, forKey: .acceptedVersion)
        try container.encodeIfPresent(accepted, forKey: .accepted)
    }

    var hasAcceptedCurrentVersion: Bool {
        accepted == true
    }
}

struct AcceptEULARequest: Codable {
    let version: Int
}

final class EULAApi {
    static let shared = EULAApi()

    private init() {}

    func getAcceptanceStatus() async throws -> EULAAcceptanceStatus {
        try await APIClient.shared.request(
            .getEULAAcceptanceStatus,
            responseType: EULAAcceptanceStatus.self
        )
    }

    func accept(version: Int) async throws {
        _ = try await APIClient.shared.request(
            .acceptEULA(version: version),
            responseType: EmptyResponse.self
        )
    }
}
