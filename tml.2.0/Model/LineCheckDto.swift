import Foundation

struct LineCheckDto: Identifiable, Codable {
    let id: String
    let userId: String?
    let username: String?

    let checkTime: Date?
    let completedAt: Date?

    let durationSeconds: Int?

    var stations: [LineCheckStationDto]
}
