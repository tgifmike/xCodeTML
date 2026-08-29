import Foundation

struct LineCheckItemDto: Identifiable, Codable, Equatable {

    let id: String?
    let itemName: String?
    let itemType: String?
    let shelfLife: String?
    let templateNotes: String?
    let tempTaken: Bool
    let checkMark: Bool
    let panSize: String?
    let tool: Bool
    let toolName: String?
    let portioned: Bool
    let portionSize: String?
    var itemChecked: Bool?
    var temperature: Float?
    let minTemp: Float?
    let maxTemp: Float?
    var observations: String?
    var correctiveNotes: String?
    var isMissing: Bool?
    var isCorrected: Bool?
    var criterionResponses: [LineCheckCriterionResponseDto]?
    var sortOrder: Int? = 0

    enum CodingKeys: String, CodingKey {
        case id
        case itemName
        case itemType
        case shelfLife
        case templateNotes
        case tempTaken
        case checkMark
        case panSize
        case tool
        case toolName
        case portioned
        case portionSize
        case itemChecked
        case temperature
        case minTemp
        case maxTemp
        case observations
        case correctiveNotes
        case isMissing
        case missing
        case isCorrected
        case corrected
        case criterionResponses
        case sortOrder
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id)
        itemName = try container.decodeIfPresent(String.self, forKey: .itemName)
        itemType = try container.decodeIfPresent(String.self, forKey: .itemType)
        shelfLife = try container.decodeIfPresent(String.self, forKey: .shelfLife)
        templateNotes = try container.decodeIfPresent(String.self, forKey: .templateNotes)
        tempTaken = try container.decodeIfPresent(Bool.self, forKey: .tempTaken) ?? false
        checkMark = try container.decodeIfPresent(Bool.self, forKey: .checkMark) ?? false
        panSize = try container.decodeIfPresent(String.self, forKey: .panSize)
        tool = try container.decodeIfPresent(Bool.self, forKey: .tool) ?? false
        toolName = try container.decodeIfPresent(String.self, forKey: .toolName)
        portioned = try container.decodeIfPresent(Bool.self, forKey: .portioned) ?? false
        portionSize = try container.decodeIfPresent(String.self, forKey: .portionSize)
        itemChecked = try container.decodeIfPresent(Bool.self, forKey: .itemChecked)
        temperature = try container.decodeIfPresent(Float.self, forKey: .temperature)
        minTemp = try container.decodeIfPresent(Float.self, forKey: .minTemp)
        maxTemp = try container.decodeIfPresent(Float.self, forKey: .maxTemp)
        observations = try container.decodeIfPresent(String.self, forKey: .observations)
        correctiveNotes = try container.decodeIfPresent(String.self, forKey: .correctiveNotes)
        isMissing = try container.decodeIfPresent(Bool.self, forKey: .isMissing)
        ?? container.decodeIfPresent(Bool.self, forKey: .missing)
        isCorrected = try container.decodeIfPresent(Bool.self, forKey: .isCorrected)
        ?? container.decodeIfPresent(Bool.self, forKey: .corrected)
        criterionResponses = try container.decodeIfPresent(
            [LineCheckCriterionResponseDto].self,
            forKey: .criterionResponses
        )
        sortOrder = try container.decodeIfPresent(Int.self, forKey: .sortOrder) ?? 0
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(id, forKey: .id)
        try container.encodeIfPresent(itemName, forKey: .itemName)
        try container.encodeIfPresent(itemType, forKey: .itemType)
        try container.encodeIfPresent(shelfLife, forKey: .shelfLife)
        try container.encode(tempTaken, forKey: .tempTaken)
        try container.encode(checkMark, forKey: .checkMark)
        try container.encodeIfPresent(panSize, forKey: .panSize)
        try container.encode(tool, forKey: .tool)
        try container.encodeIfPresent(toolName, forKey: .toolName)
        try container.encode(portioned, forKey: .portioned)
        try container.encodeIfPresent(portionSize, forKey: .portionSize)
        try container.encodeIfPresent(itemChecked, forKey: .itemChecked)
        try container.encodeIfPresent(temperature, forKey: .temperature)
        try container.encodeIfPresent(minTemp, forKey: .minTemp)
        try container.encodeIfPresent(maxTemp, forKey: .maxTemp)
        try container.encodeIfPresent(observations, forKey: .observations)
        try container.encodeIfPresent(correctiveNotes, forKey: .correctiveNotes)
        try container.encodeIfPresent(isMissing, forKey: .isMissing)
        try container.encodeIfPresent(isMissing, forKey: .missing)
        try container.encodeIfPresent(isCorrected, forKey: .isCorrected)
        try container.encodeIfPresent(isCorrected, forKey: .corrected)
        try container.encodeIfPresent(criterionResponses, forKey: .criterionResponses)
        try container.encodeIfPresent(sortOrder, forKey: .sortOrder)
    }
}
