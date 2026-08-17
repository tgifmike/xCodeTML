import SwiftUI

struct LocationDetailView: View {

    let locationId: String
    let account: Account
    let locationName: String

    @EnvironmentObject var sessionManager: SessionManager
    @EnvironmentObject var appSettings: AppSettings

    var body: some View {
        content
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    ProfileMenuView()
                        .environmentObject(sessionManager)
                }
            }
    }
}

private extension LocationDetailView {

    var content: some View {
        VStack(alignment: .leading, spacing: 20) {
            header
            dashboardActions
            Spacer()
        }
        .padding()
    }

    var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Spacer()
                accountImage
                Spacer()
            }
            .padding(.top, 8)

            Text("Dashboard")
                .font(.title.bold())

            Text(locationName)
                .font(.headline)

            Text("Account: \(account.name)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    var dashboardActions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Line Checks")
                .font(.headline)

            NavigationLink {
                LocationStationsView(
                    locationId: locationId,
                    locationName: locationName,
                    account: account
                )
                .environmentObject(sessionManager)
            } label: {
                DashboardActionCard(
                    title: "Begin Line Check",
                    subtitle: "Select stations for this location",
                    systemImage: "checklist"
                )
            }
            .buttonStyle(.plain)

            if appSettings.canViewLineCheckHistory {
                NavigationLink {
                    LineCheckHistoryView(
                        locationId: locationId,
                        locationName: locationName,
                        accountName: account.name
                    )
                } label: {
                    DashboardActionCard(
                        title: "Line Check History",
                        subtitle: "View completed checks for this location",
                        systemImage: "clock.arrow.circlepath"
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    var accountImage: some View {
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
        .frame(width: 100, height: 100)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct DashboardActionCard: View {

    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.title2.weight(.semibold))
                .foregroundStyle(.blue)
                .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "arrow.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.primary)
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
}
