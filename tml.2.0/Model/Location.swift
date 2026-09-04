struct Location: Identifiable, Codable {
    let id: String
    let name: String
    let active: Bool
    let accountId: String?

    init(id: String, name: String, active: Bool, accountId: String? = nil) {
        self.id = id
        self.name = name
        self.active = active
        self.accountId = accountId
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name = "locationName"
        case active = "locationActive"
        case accountId
    }
}
