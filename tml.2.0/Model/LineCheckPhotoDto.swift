import Foundation

struct LineCheckPhotoDto: Identifiable, Codable, Equatable {
    let id: String
    let s3Key: String?
    let originalFileName: String?
    let contentType: String?
    let photoType: LineCheckPhotoType
    let notes: String?
    let createdAt: Date?
    let createdBy: String?
    let url: String?
}

enum LineCheckPhotoType: String, Codable, CaseIterable, Identifiable {
    case item = "BEFORE"
    case corrective = "CORRECTIVE"
    case criterion = "CRITERION"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .item:
            return "Before"
        case .corrective:
            return "Corrective"
        case .criterion:
            return "Criterion"
        }
    }
}
