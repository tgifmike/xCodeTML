//
//  ProfileMenuView.swift
//  tml.2.0
//
//  Created by mike on 4/13/26.
//

import SwiftUI
import GoogleSignIn

struct ProfileMenuView: View {

    @EnvironmentObject var sessionManager: SessionManager

    var body: some View {

        Menu {

            NavigationLink {

                if let session = sessionManager.session {

                    UserProfileView()
                }

            } label: {

                Label("Profile",
                      systemImage: "person.crop.circle")
            }

            Button() {

                signOut()

            } label: {

                Label("Sign Out",
                      systemImage: "rectangle.portrait.and.arrow.right")
            }

        } label: {

            profileImage
                .frame(width: 34, height: 34)
                .clipShape(Circle())
        }
    }

    private var profileImage: some View {

        if let imageUrl = sessionManager.session?.userImage,
           let url = URL(string: imageUrl) {

            return AnyView(
                AsyncImage(url: url) { image in
                    image.resizable()
                } placeholder: {
                    ProgressView()
                }
            )

        } else {

            return AnyView(
                Image(systemName: "person.circle.fill")
                    .resizable()
            )
        }
    }

    private func signOut() {

        GIDSignIn.sharedInstance.signOut()

        sessionManager.logout()
    }
}
