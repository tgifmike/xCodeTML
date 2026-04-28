import Foundation

final class AccountApi {

    static let shared = AccountApi()
    private init() {}

    func getAccountsForUser(userId: String) async throws -> [Account] {

        try await APIClient.shared.request(
            .getAccounts(userId: userId),
            responseType: [Account].self
        )
    }
}
