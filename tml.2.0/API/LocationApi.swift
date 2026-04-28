import Foundation

final class LocationApi {

    static let shared = LocationApi()
    private init() {}

    // MARK: - Locations for Account
    func getLocationsForAccount(accountId: String) async throws -> [Location] {
        try await APIClient.shared.request(
            .getLocationsForAccount(accountId: accountId),
            responseType: [Location].self
        )
    }

    // MARK: - Locations for User
    func getLocationsForUser(userId: String) async throws -> [Location] {

            try await APIClient.shared.request(
                .getLocationsForUser(userId: userId),
                responseType: [Location].self
            )
        }
}
