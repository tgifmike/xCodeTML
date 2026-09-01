import Foundation

struct PendingLineCheckSubmission: Identifiable, Codable {
    let id: String
    let lineCheck: LineCheckDto
    let locationId: String
    let locationName: String
    let accountName: String
    let userId: String?
    let stationIds: [String]
    let requiresRemoteCreation: Bool
    let createdAt: Date

    init(
        lineCheck: LineCheckDto,
        locationId: String,
        locationName: String,
        accountName: String,
        userId: String? = nil,
        stationIds: [String] = [],
        requiresRemoteCreation: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = lineCheck.id
        self.lineCheck = lineCheck
        self.locationId = locationId
        self.locationName = locationName
        self.accountName = accountName
        self.userId = userId
        self.stationIds = stationIds
        self.requiresRemoteCreation = requiresRemoteCreation
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case lineCheck
        case locationId
        case locationName
        case accountName
        case userId
        case stationIds
        case requiresRemoteCreation
        case createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        lineCheck = try container.decode(LineCheckDto.self, forKey: .lineCheck)
        locationId = try container.decode(String.self, forKey: .locationId)
        locationName = try container.decode(String.self, forKey: .locationName)
        accountName = try container.decode(String.self, forKey: .accountName)
        userId = try container.decodeIfPresent(String.self, forKey: .userId)
        stationIds = try container.decodeIfPresent([String].self, forKey: .stationIds) ?? []
        requiresRemoteCreation = try container.decodeIfPresent(Bool.self, forKey: .requiresRemoteCreation) ?? false
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
    }
}
