import Foundation

struct PendingLineCheckPhoto: Identifiable, Codable, Equatable {
    let id: String
    let localLineCheckId: String
    let locationId: String
    let lineCheckItemId: String?
    let stationName: String
    let itemName: String
    let criterionResponseId: String?
    let criterionLabel: String?
    let photoType: LineCheckPhotoType
    let notes: String?
    let fileName: String
    let relativeFilePath: String
    let createdAt: Date
}
