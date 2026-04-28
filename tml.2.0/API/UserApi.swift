//
//  UserApi.swift
//  tml.2.0
//
//  Created by mike on 4/13/26.
//

import Foundation

final class UserApi {

    static let shared = UserApi()

    private init() {}

    // MARK: - Delete User

    func deleteUser(userId: String) async throws {

        _ = try await APIClient.shared.request(
            .deleteUser(userId: userId),
            responseType: EmptyResponse.self
        )
    }
}
