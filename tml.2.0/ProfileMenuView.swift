//
//  ProfileMenuView.swift
//  tml.2.0
//
//  Created by mike on 4/13/26.
//

import SwiftUI
import GoogleSignIn

struct ProfileMenuView: View {

    let session: UserSession
    let onLogout: () -> Void

    var body: some View {

        Menu {

            NavigationLink {
                UserProfileView(session: session, onLogout: onLogout)
            } label: {
                Label("Profile", systemImage: "person.crop.circle")
            }

            Button(role: .destructive) {
                signOut()
            } label: {
                Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
            }

        } label: {

            profileImage
                .frame(width: 34, height: 34)
                .clipShape(Circle())
        }
    }

    private var profileImage: some View {

        Group {

            if let imageUrl = session.userImage,
               let url = URL(string: imageUrl) {

                AsyncImage(url: url) { image in
                    image.resizable()
                } placeholder: {
                    ProgressView()
                }

            } else {

                Image(systemName: "person.circle.fill")
                    .resizable()
            }
        }
    }

    private func signOut() {

        GIDSignIn.sharedInstance.signOut()
        onLogout()
    }
}
