import Foundation

struct LineCheckItemDto: Identifiable, Codable {

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
    let itemChecked: Bool
    let temperature: Float?
    let minTemp: Float?
    let maxTemp: Float?
    let observations: String?
    let sortOrder: Int? = 0
}
