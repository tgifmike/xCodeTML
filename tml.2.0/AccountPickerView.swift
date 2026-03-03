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
                    
                    Text("Welcome, \(session.userName)")
                        .font(.title)
                        .padding(.horizontal)
                        .foregroundStyle(Color(Color.blue))
                    
                    Text("Select your account:")
                        .font(.headline)
                        .padding(.horizontal)
                    
//                    if isLoading {
//                        ProgressView()
//                            .frame(maxWidth: .infinity)
//                            .padding()
//                    }
                    
                    List(accounts) { account in
                        NavigationLink(
                            destination: AccountDetailView(
                                accountId: account.id,
                                accountName: account.name,
                                userId: session.userId,
                                onLogout: onLogout
                            )
                        ) {
                            HStack {
                                Text(account.name)
                                Spacer()
                                
                                if account.active {
                                    Text("Active")
                                        .foregroundColor(.green)
                                        .font(.caption)
                                }
                            }
                        }
                        
                        //                    List(accounts) { account in
                        //                        HStack {
                        //                            Text(account.name)
                        //                                .font(.headline)
                        //
                        //                            Spacer()
                        //
                        //                            if account.active {
                        //                                Text("Active")
                        //                                    .foregroundColor(.green)
                        //                                    .font(.caption)
                        //                            }
                        //                        }
                        //                        .padding(.vertical, 4)
                        //                    }
                        //                }
                    }
                    //   .navigationTitle("Select Account:")
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Sign Out") {
                                signOut()
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
