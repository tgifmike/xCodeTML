import Foundation

struct LineCheckDto: Identifiable, Codable  {
    let id: String
    let username: String?
    var stations: [LineCheckStationDto]
}
