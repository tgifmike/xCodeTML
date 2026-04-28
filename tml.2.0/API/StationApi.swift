import Foundation

final class StationApi {

    static let shared = StationApi()

    private init() {}

    func getStationsByLocation(locationId: String) async throws -> [Station] {

        let stations: [Station] = try await APIClient.shared.request(
            .getStationsByLocation(locationId: locationId),
            responseType: [Station].self
        )

        return stations.sorted {
            ($0.sortOrder ?? 0) < ($1.sortOrder ?? 0)
        }
    }
}
