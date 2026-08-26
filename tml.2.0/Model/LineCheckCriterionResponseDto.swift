import Foundation

struct LineCheckCriterionResponseDto: Identifiable, Codable, Equatable {
    let id: String?
    let itemCriterionId: String?
    let criterionId: String?
    let criterionName: String?
    let criterionType: String?
    let label: String?
    let responseType: String?
    let required: Bool?
    let requireNotesOnFailure: Bool?
    let sortOrder: Int?
    let minValue: Float?
    let maxValue: Float?
    let unit: String?
    let active: Bool?

    var booleanAnswer: Bool?
    var numberAnswer: Float?
    var textAnswer: String?
    var notes: String?
    var requiresCorrection: Bool?
    var photoCount: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case itemCriterionId
        case criterionId
        case criterionName
        case criterionType
        case label
        case responseType
        case required
        case requireNotesOnFailure
        case sortOrder
        case minValue
        case maxValue
        case unit
        case active
        case booleanAnswer
        case numberAnswer
        case textAnswer
        case notes
        case requiresCorrection
        case photoCount
        case booleanValue
        case numberValue
        case textValue
        case failed
        case photoIds
    }

    enum AnswerAliasCodingKeys: String, CodingKey {
        case answerBoolean
        case answerNumber
        case answerText
        case answerNotes
        case boolAnswer
        case numericAnswer
        case booleanValue
        case numberValue
        case textValue
        case notesValue
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id)
        itemCriterionId = try container.decodeIfPresent(String.self, forKey: .itemCriterionId)
        criterionId = try container.decodeIfPresent(String.self, forKey: .criterionId) ?? itemCriterionId
        criterionName = try container.decodeIfPresent(String.self, forKey: .criterionName)
        criterionType = try container.decodeIfPresent(String.self, forKey: .criterionType)
        label = try container.decodeIfPresent(String.self, forKey: .label)
        responseType = try container.decodeIfPresent(String.self, forKey: .responseType)
        required = try container.decodeIfPresent(Bool.self, forKey: .required)
        requireNotesOnFailure = try container.decodeIfPresent(Bool.self, forKey: .requireNotesOnFailure)
        sortOrder = try container.decodeIfPresent(Int.self, forKey: .sortOrder)
        minValue = try container.decodeIfPresent(Float.self, forKey: .minValue)
        maxValue = try container.decodeIfPresent(Float.self, forKey: .maxValue)
        unit = try container.decodeIfPresent(String.self, forKey: .unit)
        active = try container.decodeIfPresent(Bool.self, forKey: .active)
        booleanAnswer = try container.decodeIfPresent(Bool.self, forKey: .booleanAnswer)
        ?? container.decodeIfPresent(Bool.self, forKey: .booleanValue)
        numberAnswer = try container.decodeIfPresent(Float.self, forKey: .numberAnswer)
        ?? container.decodeIfPresent(Float.self, forKey: .numberValue)
        textAnswer = try container.decodeIfPresent(String.self, forKey: .textAnswer)
        ?? container.decodeIfPresent(String.self, forKey: .textValue)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        requiresCorrection = try container.decodeIfPresent(Bool.self, forKey: .requiresCorrection)
        ?? container.decodeIfPresent(Bool.self, forKey: .failed)

        if let photoCount = try container.decodeIfPresent(Int.self, forKey: .photoCount) {
            self.photoCount = photoCount
        } else {
            photoCount = try container.decodeIfPresent([String].self, forKey: .photoIds)?.count
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(id, forKey: .id)
        try container.encodeIfPresent(itemCriterionId ?? criterionId, forKey: .itemCriterionId)
        try container.encodeIfPresent(criterionId, forKey: .criterionId)
        try container.encodeIfPresent(criterionName, forKey: .criterionName)
        try container.encodeIfPresent(criterionType, forKey: .criterionType)
        try container.encodeIfPresent(label, forKey: .label)
        try container.encodeIfPresent(responseType, forKey: .responseType)
        try container.encodeIfPresent(required, forKey: .required)
        try container.encodeIfPresent(requireNotesOnFailure, forKey: .requireNotesOnFailure)
        try container.encodeIfPresent(sortOrder, forKey: .sortOrder)
        try container.encodeIfPresent(minValue, forKey: .minValue)
        try container.encodeIfPresent(maxValue, forKey: .maxValue)
        try container.encodeIfPresent(unit, forKey: .unit)
        try container.encodeIfPresent(active, forKey: .active)
        try container.encodeIfPresent(booleanAnswer, forKey: .booleanAnswer)
        try container.encodeIfPresent(numberAnswer, forKey: .numberAnswer)
        try container.encodeIfPresent(textAnswer, forKey: .textAnswer)
        try container.encodeIfPresent(notes, forKey: .notes)
        try container.encodeIfPresent(requiresCorrection, forKey: .requiresCorrection)
        try container.encodeIfPresent(photoCount, forKey: .photoCount)
        try container.encodeIfPresent(booleanAnswer, forKey: .booleanValue)
        try container.encodeIfPresent(numberAnswer, forKey: .numberValue)
        try container.encodeIfPresent(textAnswer, forKey: .textValue)
        try container.encodeIfPresent(requiresCorrection, forKey: .failed)

        var aliasContainer = encoder.container(keyedBy: AnswerAliasCodingKeys.self)
        try aliasContainer.encodeIfPresent(booleanAnswer, forKey: .answerBoolean)
        try aliasContainer.encodeIfPresent(numberAnswer, forKey: .answerNumber)
        try aliasContainer.encodeIfPresent(textAnswer, forKey: .answerText)
        try aliasContainer.encodeIfPresent(notes, forKey: .answerNotes)
        try aliasContainer.encodeIfPresent(booleanAnswer, forKey: .boolAnswer)
        try aliasContainer.encodeIfPresent(numberAnswer, forKey: .numericAnswer)
        try aliasContainer.encodeIfPresent(booleanAnswer, forKey: .booleanValue)
        try aliasContainer.encodeIfPresent(numberAnswer, forKey: .numberValue)
        try aliasContainer.encodeIfPresent(textAnswer, forKey: .textValue)
        try aliasContainer.encodeIfPresent(notes, forKey: .notesValue)
    }
}
