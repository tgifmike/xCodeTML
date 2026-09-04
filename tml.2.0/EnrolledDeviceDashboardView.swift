import SwiftUI

struct EnrolledDeviceDashboardView: View {
    let accountId: String
    let locationId: String

    @EnvironmentObject var sessionManager: SessionManager
    @EnvironmentObject var appSettings: AppSettings
    @EnvironmentObject var offlineSyncCoordinator: OfflineSyncCoordinator
    @StateObject private var offlineNavigationStore = OfflineAccountLocationStore.shared

    @State private var account: Account?
    @State private var location: Location?
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if let account, let location {
                    LocationDetailView(
                        locationId: location.id,
                        account: account,
                        locationName: location.name
                    )
                    .environmentObject(sessionManager)
                    .environmentObject(appSettings)
                    .environmentObject(offlineSyncCoordinator)
                } else if isLoading {
                    ProgressView("Loading dashboard...")
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "location.slash")
                            .font(.system(size: 32))
                            .foregroundStyle(.secondary)

                        Text("Could not open dashboard")
                            .font(.headline)

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding()
                }
            }
            .task(id: "\(accountId):\(locationId)") {
                await loadDashboardContext()
            }
        }
    }

    private func loadDashboardContext() async {
        isLoading = true
        errorMessage = nil

        if let cachedAccount = offlineNavigationStore.cachedAccount(id: accountId),
           let cachedLocation = offlineNavigationStore.cachedLocation(id: locationId, accountId: accountId) {
            account = cachedAccount
            location = cachedLocation
            isLoading = false
            return
        }

        do {
            guard let session = sessionManager.session else {
                throw APIError.unauthorized("TOKEN_MISSING")
            }

            let fetchedAccounts = try await AccountApi.shared.getAccountsForUser(userId: session.userId)
            offlineNavigationStore.cacheAccounts(fetchedAccounts, userId: session.userId)

            let fetchedLocations: [Location]
            if session.authProvider == .pin {
                fetchedLocations = try await LocationApi.shared.getLocationsForUser(userId: session.userId)
            } else {
                fetchedLocations = try await LocationApi.shared.getLocationsForAccount(accountId: accountId)
            }
            offlineNavigationStore.cacheLocations(fetchedLocations, accountId: accountId)

            guard let resolvedAccount = fetchedAccounts.first(where: { $0.id == accountId }),
                  let resolvedLocation = fetchedLocations.first(where: { $0.id == locationId }) else {
                throw APIError.invalidResponse
            }

            account = resolvedAccount
            location = resolvedLocation
        } catch {
            account = nil
            location = nil
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
