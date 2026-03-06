import Foundation

struct LineCheckItemInput: Identifiable, Codable, Equatable  {
    let id: UUID

    let item: LineCheckItemDto

    var temperature: String = ""
    var observations: String = ""
    var isChecked: Bool? = nil
    var isMissing: Bool = false
    
}
