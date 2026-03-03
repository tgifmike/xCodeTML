import Foundation


struct LineCheckStationDto: Identifiable, Codable, Equatable  {
    let id: String
    let stationName: String?
    let items: [LineCheckItemDto]
}
