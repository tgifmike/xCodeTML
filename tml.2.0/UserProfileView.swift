//
//  UserProfileView.swift
//  tml.2.0
//
//  Created by mike on 4/13/26.
//

import SwiftUI
import GoogleSignIn

struct UserProfileView: View {

    @EnvironmentObject var sessionManager: SessionManager

    @State private var showDeleteAlert = false
    @State private var isDeleting = false

    var body: some View {

        Form {

            Section("User Info") {

                Text(sessionManager.session?.userName ?? "Unknown")

                Text(sessionManager.session?.email ?? "Unknown")
                    .foregroundColor(.secondary)
            }

            Section {

                Button(role: .destructive) {

                    showDeleteAlert = true

                } label: {

                    if isDeleting {
                        ProgressView()
                    } else {
                        Text("Delete Account")
                    }
                }
                .disabled(isDeleting)
            }
        }
        .navigationTitle("Profile")
        .alert("Delete Account?",
               isPresented: $showDeleteAlert) {

            Button("Delete", role: .destructive) {

                deleteAccount()

            }

            Button("Cancel", role: .cancel) {}

        } message: {

            Text("This will permanently delete your account and remove access to all data.")
        }
    }

    private func deleteAccount() {

        guard let userId = sessionManager.session?.userId else {
            return
        }

        isDeleting = true

        Task {

            await UserApi.shared.deleteUser(
                userId: userId
            )

            await MainActor.run {

                signOutUserAfterDeletion()
            }
        }
    }

    private func signOutUserAfterDeletion() {

        GIDSignIn.sharedInstance.signOut()

        sessionManager.logout()
    }
}
