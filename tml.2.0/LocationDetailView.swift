import SwiftUI
import UserNotifications

struct LocationDetailView: View {

    let locationId: String
    let account: Account
    let locationName: String

    @EnvironmentObject var sessionManager: SessionManager
    @EnvironmentObject var appSettings: AppSettings

    @State private var correctiveLineCheckCount = 0

    var body: some View {
        content
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await loadCorrectiveLineCheckCount()
            }
            .onAppear {
                Task {
                    await loadCorrectiveLineCheckCount()
                }
            }
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

            NavigationLink {
                LineCheckReconcileView(
                    locationId: locationId,
                    locationName: locationName,
                    accountName: account.name
                )
            } label: {
                DashboardActionCard(
                    title: "Corrective Actions Needed",
                    subtitle: "Review line checks that need follow-up",
                    systemImage: "exclamationmark.triangle",
                    badgeCount: correctiveLineCheckCount
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

    func loadCorrectiveLineCheckCount() async {
        do {
            let lineChecks = try await LineCheckApi.shared.getCompletedLineChecksByLocation(
                locationId: locationId
            )

            correctiveLineCheckCount = await unresolvedLineCheckCount(in: lineChecks)
            await updateAppIconBadge(correctiveLineCheckCount)
        } catch {
            correctiveLineCheckCount = 0
            await updateAppIconBadge(0)
        }
    }

    func updateAppIconBadge(_ count: Int) async {
        let center = UNUserNotificationCenter.current()

        do {
            let granted = try await center.requestAuthorization(options: [.badge])
            guard granted else { return }

            try await center.setBadgeCount(count)
        } catch {
            // Badge updates should not block dashboard use.
        }
    }

    func unresolvedLineCheckCount(in lineChecks: [LineCheckDto]) async -> Int {
        var count = 0

        for lineCheck in lineChecks {
            if await hasUnresolvedIssues(in: lineCheck) {
                count += 1
            }
        }

        return count
    }

    func hasUnresolvedIssues(in lineCheck: LineCheckDto) async -> Bool {
        for station in lineCheck.stations {
            for item in station.items where hasCorrectionIssue(item) {
                guard item.isCorrected != true else {
                    continue
                }

                if await hasCorrectivePhoto(for: item.id) == false {
                    return true
                }
            }
        }

        return false
    }

    func hasCorrectivePhoto(for itemId: String?) async -> Bool {
        guard let itemId else { return false }

        do {
            let photos = try await LineCheckPhotoApi.shared.getPhotos(lineCheckItemId: itemId)
            return photos.contains { $0.photoType == .corrective }
        } catch {
            return false
        }
    }

    func hasCorrectionIssue(_ item: LineCheckItemDto) -> Bool {
        item.isMissing == true ||
        isOutOfTemperatureRange(item) ||
        hasIncorrectPrep(item)
    }

    func isOutOfTemperatureRange(_ item: LineCheckItemDto) -> Bool {
        guard let temperature = item.temperature else { return false }

        if let minTemp = item.minTemp, temperature < minTemp {
            return true
        }

        if let maxTemp = item.maxTemp, temperature > maxTemp {
            return true
        }

        return false
    }

    func hasIncorrectPrep(_ item: LineCheckItemDto) -> Bool {
        item.itemChecked == false
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
    var badgeCount: Int = 0

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

            if badgeCount > 0 {
                Text("\(badgeCount)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .frame(minWidth: 24, minHeight: 24)
                    .padding(.horizontal, badgeCount > 9 ? 4 : 0)
                    .background(Color.red)
                    .clipShape(Capsule())
                    .accessibilityLabel("\(badgeCount) line checks need corrective action")
            }

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
