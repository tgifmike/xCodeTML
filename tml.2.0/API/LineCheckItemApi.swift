import Foundation

struct LineCheckItemCorrectionRequest: Encodable {
    let corrected: Bool
    let correctiveNotes: String?
}

final class LineCheckItemApi {

    static let shared = LineCheckItemApi()

    private init() {}

    func updateCorrection(
        itemId: String,
        corrected: Bool,
        correctiveNotes: String?
    ) async throws -> LineCheckItemDto {
        let trimmedNotes = correctiveNotes?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let request = LineCheckItemCorrectionRequest(
            corrected: corrected,
            correctiveNotes: trimmedNotes?.isEmpty == true ? nil : trimmedNotes
        )

        return try await APIClient.shared.request(
            .updateLineCheckItemCorrection(itemId: itemId, request: request),
            responseType: LineCheckItemDto.self
        )
    }
}
