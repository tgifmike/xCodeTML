struct Location: Identifiable, Codable {
    let id: String
    let name: String
    let active: Bool
    
    enum CodingKeys: String, CodingKey {
        case id
        case name = "locationName"
        case active = "locationActive"
    }
}
