//
//  DashboardView.swift
//  tml.2.0
//
//  Created by mike on 2/24/26.
//

import SwiftUI
import GoogleSignIn

struct AccountPickerView: View {
    
    let session: UserSession
    let onLogout: () -> Void
    
    @State private var accounts: [Account] = []
    @State private var isLoading = false
    @State private var hasLoaded = false
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading) {
                
                if isLoading {
                    ProgressView()
                        .padding()
                }
                
                if hasLoaded && accounts.isEmpty && !isLoading {
                    Text("No Accounts are set up for this user.\nPlease configure them on the website.")
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding()
                } else {
                    
//                    Text("Welcome, \(session.userName)")
//                        .font(.title)
//                        .padding(.horizontal)
//                        .foregroundStyle(Color(Color.blue))
                    
                    HStack(spacing: 12) {

                        if let imageUrl = session.userImage,
                           let url = URL(string: imageUrl) {

                            AsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                            } placeholder: {
                                ProgressView()
                            }
                            .frame(width: 34, height: 34)
                            .clipShape(Circle())

                        } else {

                            Image(systemName: "person.circle.fill")
                                .resizable()
                                .frame(width: 44, height: 44)
                                .foregroundColor(.gray)
                        }

                        Text("Welcome, \(session.userName)")
                            .font(.title)
                            .foregroundStyle(.blue)

                        Spacer()
                    }
                    .padding(.horizontal)
                    
                    Text("Select your account:")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    
                    List(accounts) { account in
                        NavigationLink(
                            destination: AccountDetailView(
                                session: session,
                                accountId: account.id,
                                accountName: account.name,
                                userId: session.userId,
                                onLogout: onLogout
                            )
                        ) {
                            HStack(spacing: 12) {

                                if let base64 = account.imageBase64,
                                   let data = Data(base64Encoded: base64),
                                   let uiImage = UIImage(data: data) {

                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 40, height: 40)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))

                                } else {

                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.gray.opacity(0.3))
                                        .frame(width: 40, height: 40)
                                        .overlay(
                                            Image(systemName: "building.2")
                                                .foregroundColor(.gray)
                                        )
                                }

                                Text(account.name)
                                    .font(.body)

                                Spacer()

                                if account.active {
                                    Text("Active")
                                        .foregroundColor(.green)
                                        .font(.caption)
                                }
                            }
                            .padding(.vertical, 6)
                        }
                    }
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {

                            Menu {

                                Button(role: .destructive) {
                                    signOut()
                                } label: {
                                    Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                                }

                            } label: {

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
                                .frame(width: 34, height: 34)
                                .clipShape(Circle())
                            }
                        }
                    }
                    .task {
                        await loadAccounts()
                    }
                }
            }
        }
    }
    func loadAccounts() async {
        print("🔎 Loading accounts for userId:", session.userId)
        isLoading = true
        accounts = await AccountApi.shared.getAccountsForUser(userId: session.userId)
        print("📦 Accounts returned:", accounts.count)
        hasLoaded = true
        isLoading = false
    }
    
    func signOut() {
        // Google sign out
        GIDSignIn.sharedInstance.signOut()
        onLogout()
        // You can clear session here
        //print("Signed out")
    }
}
