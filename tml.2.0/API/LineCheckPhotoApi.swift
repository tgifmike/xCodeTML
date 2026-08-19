import Foundation

final class LineCheckPhotoApi {

    static let shared = LineCheckPhotoApi()

    private init() {}

    func getPhotos(lineCheckItemId: String) async throws -> [LineCheckPhotoDto] {
        try await APIClient.shared.request(
            .getLineCheckPhotos(lineCheckItemId: lineCheckItemId),
            responseType: [LineCheckPhotoDto].self
        )
    }

    func uploadPhoto(
        lineCheckItemId: String,
        imageData: Data,
        fileName: String,
        photoType: LineCheckPhotoType,
        notes: String? = nil
    ) async throws -> LineCheckPhotoDto {

        var fields = [
            "photoType": photoType.rawValue
        ]

        if let notes, !notes.isEmpty {
            fields["notes"] = notes
        }

        return try await APIClient.shared.uploadMultipart(
            path: "/api/line-check-items/\(lineCheckItemId.urlPathSegmentEncoded)/photos",
            fileFieldName: "file",
            fileName: fileName,
            mimeType: "image/jpeg",
            fileData: imageData,
            fields: fields,
            responseType: LineCheckPhotoDto.self
        )
    }
}
