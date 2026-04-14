//
//  UserApi.swift
//  tml.2.0
//
//  Created by mike on 4/13/26.
//

import Foundation

class UserApi {

    static let shared = UserApi()

    private init() {}

    func deleteUser(userId: String) async {

        guard let url = URL(string:
            "\(Config.baseURL)/users/delete/\(userId)"
        ) else {
            print("❌ Invalid delete user URL")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {

            let (_, response) =
                try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {

                if httpResponse.statusCode == 204 {

                    print("✅ User deleted successfully")

                } else {

                    print("❌ Delete failed:", httpResponse.statusCode)
                }
            }

        } catch {

            print("❌ Delete error:", error.localizedDescription)
        }
    }
}
