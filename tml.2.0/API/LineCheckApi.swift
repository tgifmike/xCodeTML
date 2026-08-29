import Foundation

final class LineCheckApi {

    static let shared = LineCheckApi()

    private init() {}

    // MARK: - Create Line Check
    func createLineCheck(
        userId: String,
        stationIds: [String]
    ) async throws -> LineCheckDto {

        try await APIClient.shared.request(
            .createLineCheck(userId: userId, stationIds: stationIds),
            responseType: LineCheckDto.self
        )
    }

    // MARK: - Get Line Check By Id
    func getLineCheckById(
        lineCheckId: String
    ) async throws -> LineCheckDto {

        try await APIClient.shared.request(
            .getLineCheckById(lineCheckId: lineCheckId),
            responseType: LineCheckDto.self
        )
    }

    // MARK: - Completed Line Checks By Location
    func getCompletedLineChecksByLocation(
        locationId: String
    ) async throws -> [LineCheckDto] {

        try await APIClient.shared.request(
            .getCompletedLineChecksByLocation(locationId: locationId),
            responseType: [LineCheckDto].self
        )
    }

    // MARK: - Save Line Check
    func saveLineCheck(
        _ lineCheck: LineCheckDto
    ) async throws -> LineCheckDto {

        try await APIClient.shared.request(
            .saveLineCheck(lineCheck),
            responseType: LineCheckDto.self
        )
    }
}
