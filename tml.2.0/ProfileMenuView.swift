import SwiftUI
import GoogleSignIn

struct ProfileMenuView: View {

    @EnvironmentObject var sessionManager: SessionManager

    var body: some View {

        Menu {

            NavigationLink {
                UserProfileView(sessionManager: sessionManager)
            } label: {
                Label("Profile", systemImage: "person.crop.circle")
            }

            NavigationLink {
                SettingsView()
                    .environmentObject(sessionManager)
            } label: {
                Label("Settings", systemImage: "gearshape")
            }

            Divider()

            Button(role: .destructive) {
                signOut()
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
