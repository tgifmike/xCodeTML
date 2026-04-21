//
//  DashboardView.swift
//  tml.2.0
//
//  Created by mike on 2/24/26.
//

import SwiftUI
import GoogleSignIn

struct AccountPickerView: View {

    @EnvironmentObject var sessionManager: SessionManager

    @State private var accounts: [Account] = []
    @State private var isLoading = false
    @State private var hasLoaded = false
    

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Accounts")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        ProfileMenuView()
                            .environmentObject(sessionManager)
                    }
                }
                .task {
                    await loadAccounts()
                }
        }
    }
}

// MARK: - Content
private extension AccountPickerView {

    @ViewBuilder
    var content: some View {

        VStack(alignment: .leading, spacing: 16) {

            header

            if isLoading {
                ProgressView("Loading accounts...")
                    .frame(maxWidth: .infinity, alignment: .center)
            }

            else if hasLoaded && accounts.isEmpty {
                emptyState
            }

            else {
                accountList
            }

            Spacer()
        }
        .padding()
    }
}

private extension AccountPickerView {

    var header: some View {

        HStack(spacing: 12) {

            profileImage

            VStack(alignment: .leading, spacing: 2) {
                Text("Welcome")
                    .font(.caption)
                    .foregroundStyle(.blue)

                Text(sessionManager.session?.userName ?? "User")
                    .font(.title3.bold())
            }

            Spacer()
        }
    }

    var profileImage: some View {

        Group {
            if let urlString = sessionManager.session?.userImage,
               let url = URL(string: urlString) {

                AsyncImage(url: url) { image in
                    image.resizable()
                } placeholder: {
                    ProgressView()
                }

            } else {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .foregroundStyle(.gray)
            }
        }
        .frame(width: 40, height: 40)
        .clipShape(Circle())
    }
}

private extension AccountPickerView {

    var emptyState: some View {
        Text("No accounts are assigned to this user.\nPlease configure them in the web dashboard.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 40)
    }
}

//private extension AccountPickerView {
//
//    var accountList: some View {
//
//        List(accounts) { account in
//
//            NavigationLink {
//
//                AccountDetailView(
//                    account: account
//                )
//
//            } label: {
//
//                HStack(spacing: 12) {
//
//                    accountImage(account)
//
//                    Text(account.name)
//                        .font(.body)
//
//                    Spacer()
//                }
//                .padding(.vertical, 6)
//            }
//        }
//        .listStyle(.plain)
//    }
//
//    func accountImage(_ account: Account) -> some View {
//
//        Group {
//            if let base64 = account.imageBase64,
//               let data = Data(base64Encoded: base64),
//               let uiImage = UIImage(data: data) {
//
//                Image(uiImage: uiImage)
//                    .resizable()
//                    .scaledToFill()
//
//            } else {
//                RoundedRectangle(cornerRadius: 8)
//                    .fill(Color.gray.opacity(0.3))
//                    .overlay(
//                        Image(systemName: "building.2")
//                            .foregroundStyle(.gray)
//                    )
//            }
//        }
//        .frame(width: 40, height: 40)
//        .clipShape(RoundedRectangle(cornerRadius: 8))
//    }
//}

private extension AccountPickerView {

    var accountList: some View {

        ScrollView {

            LazyVStack(spacing: 12) {

                ForEach(accounts) { account in

                    NavigationLink {

                        AccountDetailView(account: account)

                    } label: {

                        AccountCard(account: account)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 8)
        }
    }
}

private extension AccountPickerView {

    func loadAccounts() async {

        guard let userId = sessionManager.session?.userId else {
            accounts = []
            hasLoaded = true
            return
        }

        isLoading = true
        hasLoaded = false

        accounts = await AccountApi.shared.getAccountsForUser(userId: userId)

        isLoading = false
        hasLoaded = true
    }
}

private struct AccountCard: View {

    let account: Account

    var body: some View {

        HStack(spacing: 14) {

            accountImage

            VStack(alignment: .leading, spacing: 4) {

                Text(account.name)
                    .font(.headline)

//                Text("Account")
//                    .font(.caption)
//                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "arrow.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 3)
    }

    private var accountImage: some View {

        Group {
            if let base64 = account.imageBase64,
               let data = Data(base64Encoded: base64),
               let uiImage = UIImage(data: data) {

                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()

            } else {
                Image(systemName: "building.2.crop.circle")
                    .resizable()
                    .foregroundStyle(.gray)
            }
        }
        .frame(width: 40, height: 40)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
