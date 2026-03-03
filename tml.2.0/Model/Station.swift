import Foundation

struct Station: Identifiable, Codable {
    var id: String
    var stationName: String
    var sortOrder: Int?
}
