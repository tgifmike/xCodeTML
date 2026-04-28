//
//  UserProfileView.swift
//  tml.2.0
//

import SwiftUI
import GoogleSignIn

struct UserProfileView: View {

    @EnvironmentObject var sessionManager: SessionManager

    @State private var showDeleteAlert = false
    @State private var isDeleting = false

    private var session: UserSession? {
        sessionManager.session
    }

    var body: some View {

        Form {

            profileHeaderSection

            userInfoSection

            accountActionsSection

            #if DEBUG
            debugSection
            #endif
        }
        .navigationTitle("Profile")
        .alert(
            "Delete Account?",
            isPresented: $showDeleteAlert
        ) {

            Button("Delete", role: .destructive) {
                deleteAccount()
            }

            Button("Cancel", role: .cancel) { }

        } message: {

            Text("This will permanently delete your account and remove access to all data.")
        }
    }
}

//////////////////////////////////////////////////////////////
// MARK: HEADER
//////////////////////////////////////////////////////////////

private extension UserProfileView {

    var profileHeaderSection: some View {

        Section {

            VStack(spacing: 12) {

                profileImage

                Text(session?.userName ?? "Unknown User")
                    .font(.headline)

                Text(session?.email ?? "")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

//////////////////////////////////////////////////////////////
// MARK: USER INFO
//////////////////////////////////////////////////////////////

private extension UserProfileView {

    var userInfoSection: some View {

        Section("User Info") {

            profileRow("User ID", session?.userId)

            profileRow("App Role", session?.appRole)

            profileRow("Access Role", session?.accessRole)

            profileRow("Sign-In Method", session?.authProvider.displayName)        }
    }
}

//////////////////////////////////////////////////////////////
// MARK: ACCOUNT ACTIONS
//////////////////////////////////////////////////////////////

private extension UserProfileView {

    var accountActionsSection: some View {

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
}

//////////////////////////////////////////////////////////////
// MARK: DEBUG SECTION
//////////////////////////////////////////////////////////////

private extension UserProfileView {

    var debugSection: some View {

        Section("Debug Info") {

            profileRow("JWT", session?.jwt)
        }
    }
}

//////////////////////////////////////////////////////////////
// MARK: HELPERS
//////////////////////////////////////////////////////////////

private extension UserProfileView {

    func profileRow(
        _ title: String,
        _ value: String?
    ) -> some View {

        HStack {

            Text(title)

            Spacer()

            Text(value ?? "Unknown")
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
    }

    var profileImage: some View {

        Group {

            if let urlString = session?.userImage,
               let url = URL(string: urlString) {

                AsyncImage(url: url) {

                    $0.resizable()

                } placeholder: {

                    ProgressView()
                }

            } else {

                Image(systemName: "person.circle.fill")
                    .resizable()
                    .foregroundStyle(.gray)
            }
        }
        .frame(width: 80, height: 80)
        .clipShape(Circle())
    }
}

//////////////////////////////////////////////////////////////
// MARK: DELETE ACCOUNT
//////////////////////////////////////////////////////////////

private extension UserProfileView {

    func deleteAccount() {

        guard let userId = session?.userId else {
            return
        }

        isDeleting = true

        Task {

            do {
                try await UserApi.shared.deleteUser(userId: userId)

                await MainActor.run {
                    signOutUserAfterDeletion()
                    isDeleting = false
                }

            } catch {

                await MainActor.run {
                    isDeleting = false
                    print("❌ Delete failed:", error.localizedDescription)
                }
            }
        }
    }

    func signOutUserAfterDeletion() {

        GIDSignIn.sharedInstance.signOut()

        sessionManager.logout()
    }
}
