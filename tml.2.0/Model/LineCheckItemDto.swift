import Foundation

struct LineCheckItemDto: Identifiable, Codable, Equatable {

    let id: String?
    let itemName: String?
    let shelfLife: String?
    let templateNotes: String?
    let tempTaken: Bool
    let checkMark: Bool
    let panSize: String?
    let tool: Bool
    let toolName: String?
    let portioned: Bool
    let portionSize: String?
    var itemChecked: Bool
    var temperature: Float?
    let minTemp: Float?
    let maxTemp: Float?
    var observations: String?
    var isMissing: Bool?
    let sortOrder: Int? = 0
}
