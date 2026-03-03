import Foundation

struct Account: Identifiable, Codable {
    let id: String
    let name: String
    let imageBase64: String?
    let active: Bool
    
    enum CodingKeys: String, CodingKey {
        case id
        case name = "accountName"
        case imageBase64
        case active = "accountActive"
    }
}
