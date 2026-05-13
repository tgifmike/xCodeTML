//
//  UserProfileViewModel.swift
//  tml.2.0
//
//  Created by mike on 5/13/26.
//

import Foundation
import SwiftUI
import GoogleSignIn
import Combine

@MainActor
final class UserProfileViewModel: ObservableObject {

    @Published var showDeleteSheet = false
    @Published var isDeleting = false
    @Published var errorMessage: String?
    @Published var didDeleteAccount = false

    private let sessionManager: SessionManager

    init(sessionManager: SessionManager) {
        self.sessionManager = sessionManager
    }

    var session: UserSession? {
        sessionManager.session
    }

    func openDeleteSheet() {
        errorMessage = nil
        showDeleteSheet = true
    }

    func cancelDelete() {
        errorMessage = nil
        showDeleteSheet = false
    }

    func confirmDelete() {

        guard let userId = session?.userId else {
            errorMessage = "Missing user session."
            return
        }

        isDeleting = true
        errorMessage = nil

        Task {
            do {
                try await UserApi.shared.deleteUser(userId: userId)

                await MainActor.run {
                    isDeleting = false
                    showDeleteSheet = false
                }

                // IMPORTANT: delay session teardown slightly
                try? await Task.sleep(nanoseconds: 200_000_000)

                await MainActor.run {
                    GIDSignIn.sharedInstance.signOut()
                    sessionManager.logout()
                }

            } catch {

                await MainActor.run {
                    isDeleting = false
                    errorMessage = mapError(error)
                }
            }
        }
    }

    private func mapError(_ error: Error) -> String {

        let nsError = error as NSError

        // HTTP errors from URLSession usually come through here
        if nsError.domain == NSURLErrorDomain {
            return "Network error. Please try again."
        }

        if let statusCode = nsError.userInfo["statusCode"] as? Int {

            switch statusCode {
            case 403:
                return "Demo users cannot delete accounts."
            case 404:
                return "User not found."
            default:
                return "Request failed. Please try again."
            }
        }

        return nsError.localizedDescription
    }
}
