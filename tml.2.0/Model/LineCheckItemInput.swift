import Foundation

struct LineCheckItemInput: Identifiable, Codable  {
    let id: UUID

    let item: LineCheckItemDto

    var temperature: String = ""
    var observations: String = ""
    var isPrepared: Bool = false 
    
}
