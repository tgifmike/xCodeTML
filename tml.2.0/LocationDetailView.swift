import SwiftUI
import UserNotifications

struct LocationDetailView: View {

    let locationId: String
    let account: Account
    let locationName: String

    @EnvironmentObject var sessionManager: SessionManager
    @EnvironmentObject var appSettings: AppSettings
    @EnvironmentObject var offlineSyncCoordinator: OfflineSyncCoordinator

    @StateObject private var offlineStore = OfflineLineCheckStore.shared
    @StateObject private var offlinePhotoStore = OfflineLineCheckPhotoStore.shared
    @State private var correctiveItemCount = 0
    @State private var locallyCorrectedItemIds: Set<String> = []
    @State private var offlineSyncMessage = ""
    @State private var isShowingOfflineSyncMessage = false

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
            .task {
                for await notification in NotificationCenter.default.notifications(named: .lineCheckCorrectionsDidChange) {
                    if let itemId = notification.userInfo?[LineCheckCorrectionNotificationKey.itemId] as? String {
                        locallyCorrectedItemIds.insert(itemId)
                    }

                    await loadCorrectiveLineCheckCount()
                }
            }
            .alert("Offline Sync", isPresented: $isShowingOfflineSyncMessage) {
                Button("OK") { }
            } message: {
                Text(offlineSyncMessage)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    ProfileMenuView(pinEnrollmentAccount: account)
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


            if pendingOfflineSyncCount > 0 {
                Button {
                    Task {
                        await syncOfflineLineChecks()
                    }
                } label: {
                    DashboardActionCard(
                        title: "Offline Work",
                        subtitle: offlineSyncCoordinator.isSyncing
                        ? "Syncing saved work..."
                        : offlineSyncSubtitle,
                        systemImage: "arrow.triangle.2.circlepath",
                        badgeCount: pendingOfflineSyncCount
                    )
                }
                .buttonStyle(.plain)
                .disabled(offlineSyncCoordinator.isSyncing)
            }

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
                    badgeCount: correctiveItemCount
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


    var pendingOfflineLineCheckCount: Int {
        offlineStore.pendingCount(for: locationId)
    }

    var pendingOfflinePhotoCount: Int {
        offlinePhotoStore.pendingCount(forLocationId: locationId)
    }

    var pendingOfflineSyncCount: Int {
        pendingOfflineLineCheckCount + pendingOfflinePhotoCount
    }

    var offlineSyncSubtitle: String {
        var parts: [String] = []

        if pendingOfflineLineCheckCount > 0 {
            let label = pendingOfflineLineCheckCount == 1 ? "check" : "checks"
            parts.append("\(pendingOfflineLineCheckCount) \(label)")
        }

        if pendingOfflinePhotoCount > 0 {
            let label = pendingOfflinePhotoCount == 1 ? "photo" : "photos"
            parts.append("\(pendingOfflinePhotoCount) \(label)")
        }

        return "\(parts.joined(separator: ", ")) waiting to sync"
    }

    func syncOfflineLineChecks() async {
        await offlineSyncCoordinator.syncNow()
        await loadCorrectiveLineCheckCount()

        offlineSyncMessage = offlineSyncCoordinator.lastSyncSummary
        ?? offlineSyncCoordinator.lastErrorMessage
        ?? "No offline work is waiting to sync."
        isShowingOfflineSyncMessage = true
    }


    func loadCorrectiveLineCheckCount() async {
        do {
            let lineChecks = try await LineCheckApi.shared.getCompletedLineChecksByLocation(
                locationId: locationId
            )

            correctiveItemCount = unresolvedCorrectionItemCount(in: lineChecks)
            await updateAppIconBadge(correctiveItemCount)
        } catch {
            correctiveItemCount = 0
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

    func unresolvedCorrectionItemCount(in lineChecks: [LineCheckDto]) -> Int {
        var count = 0

        for lineCheck in lineChecks {
            for station in lineCheck.stations {
                count += station.items.filter { item in
                    LineCheckCorrectionRules.hasCorrectionIssue(item) && !isResolved(item)
                }.count
            }
        }

        return count
    }

    func isResolved(_ item: LineCheckItemDto) -> Bool {
        if item.isCorrected == true {
            return true
        }

        guard let itemId = item.id else {
            return false
        }

        return locallyCorrectedItemIds.contains(itemId)
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
