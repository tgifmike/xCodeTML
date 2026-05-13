//
//  UserProfileView.swift
//  tml.2.0
//

import SwiftUI

struct UserProfileView: View {

    @StateObject private var vm: UserProfileViewModel

    init(sessionManager: SessionManager) {
        _vm = StateObject(
            wrappedValue: UserProfileViewModel(sessionManager: sessionManager)
        )
    }

    var body: some View {
        Form {
            profileHeader
            userInfo
            actions
        }
        .navigationTitle("Profile")
        .sheet(isPresented: $vm.showDeleteSheet) {
            deleteSheet
        }
    }
}

private extension UserProfileView {

    var profileHeader: some View {
        Section {
            VStack(spacing: 12) {

                profileImage

                Text(vm.session?.userName ?? "Unknown User")
                    .font(.headline)

                Text(vm.session?.email ?? "")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

private extension UserProfileView {

    var userInfo: some View {
        Section("User Info") {

            profileRow("User ID", vm.session?.userId)
            profileRow("App Role", vm.session?.appRole)
            profileRow("Access Role", vm.session?.accessRole)
            profileRow("Sign-In Method", vm.session?.authProvider.displayName)
        }
    }
}

private extension UserProfileView {

    var actions: some View {
        
        Section {
            
            Button(role: .destructive) {
                vm.openDeleteSheet()
            } label: {
                
                if vm.isDeleting {
                    
                    ProgressView()
                    
                } else {
                    
                    Text("Delete Account")
                }
            }
            .disabled(vm.isDeleting)
        }
    }
}

private extension UserProfileView {

    var debugSection: some View {
        Section("Debug Info") {
            profileRow("JWT", vm.session?.jwt)
        }
    }
}

private extension UserProfileView {

    func profileRow(_ title: String, _ value: String?) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value ?? "Unknown")
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
    }
}

private extension UserProfileView {

    var profileImage: some View {
        Group {
            if let urlString = vm.session?.userImage,
               let url = URL(string: urlString) {

                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .foregroundStyle(.gray)
                    }
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

private extension UserProfileView {

    var deleteSheet: some View {
        VStack(spacing: 20) {

            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundStyle(.red)

            Text("Delete Account?")
                .font(.title2)
                .bold()

            Text("This action is permanent and cannot be undone.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            if vm.isDeleting {
                ProgressView("Deleting...")
            } else {

                Button(role: .destructive) {
                    vm.confirmDelete()
                } label: {
                    Text("Yes, Delete My Account")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button("Cancel") {
                    vm.cancelDelete()
                }
            }
        }
        .padding()
        .presentationDetents([.medium])
    }
}
