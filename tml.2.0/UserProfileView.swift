//
//  UserProfileView.swift
//  tml.2.0
//
//  Created by mike on 4/13/26.
//

import SwiftUI
import GoogleSignIn

struct UserProfileView: View {

    let session: UserSession
    let onLogout: () -> Void

    @State private var showDeleteAlert = false
    @State private var isDeleting = false

    var body: some View {

        Form {

            Section("User Info") {

                Text(session.userName)

                Text(session.email)
                    .foregroundColor(.secondary)
            }

            Section {

                Button(role: .destructive) {

                    showDeleteAlert = true

                } label: {

                    Text("Delete Account")
                }

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

        isDeleting = true

        Task {

            await UserApi.shared.deleteUser(
                userId: session.userId
            )

            await MainActor.run {

                signOutUserAfterDeletion()
            }
        }
    }
    
    private func signOutUserAfterDeletion() {

        GIDSignIn.sharedInstance.signOut()
        
        onLogout()

        // navigate back to login screen
    }
}
