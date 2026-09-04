import SwiftUI
import GoogleSignIn

struct ProfileMenuView: View {

    var pinEnrollmentAccount: Account? = nil

    @EnvironmentObject var sessionManager: SessionManager
    @State private var showSignOutConfirmation = false

    var body: some View {

        Menu {

            NavigationLink {
                UserProfileView(sessionManager: sessionManager)
            } label: {
                Label("Profile", systemImage: "person.crop.circle")
            }

            NavigationLink {
                OfflineSyncView()
            } label: {
                Label("Offline Sync", systemImage: "arrow.triangle.2.circlepath")
            }

            NavigationLink {
                SettingsView(pinEnrollmentAccount: pinEnrollmentAccount)
                    .environmentObject(sessionManager)
            } label: {
                Label("Settings", systemImage: "gearshape")
            }

            Divider()

            Button(role: .destructive) {
                showSignOutConfirmation = true
            } label: {
                Label(
                    "Sign Out",
                    systemImage: "rectangle.portrait.and.arrow.right"
                )
            }

        } label: {

            profileImage
                .frame(width: 34, height: 34)
                .clipShape(Circle())
        }
        .alert("Sign Out?", isPresented: $showSignOutConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Sign Out", role: .destructive) {
                signOut()
            }
        } message: {
            Text("Do you really want to sign out?")
        }
    }

    // MARK: - Profile Image

    private var profileImage: some View {

        Group {

            if let urlString = sessionManager.session?.userImage,
               let url = URL(string: urlString) {

                AsyncImage(url: url) { phase in

                    switch phase {

                    case .success(let image):

                        image
                            .resizable()
                            .scaledToFill()

                    default:

                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .scaledToFill()
                    }
                }

            } else {

                Image(systemName: "person.circle.fill")
                    .resizable()
                    .scaledToFill()
            }
        }
    }

    // MARK: - Sign Out

    private func signOut() {

        GIDSignIn.sharedInstance.signOut()
        sessionManager.logout()
    }
}
