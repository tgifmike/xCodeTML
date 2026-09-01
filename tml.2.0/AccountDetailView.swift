import SwiftUI
import GoogleSignIn

struct AccountDetailView: View {

    @EnvironmentObject var sessionManager: SessionManager

//    let accountId: String
//    let accountName: String
    
    let account: Account

    @StateObject private var offlineNavigationStore = OfflineAccountLocationStore.shared
    @State private var locations: [Location] = []
    @State private var isLoading = false
    @State private var hasLoaded = false
    @State private var isUsingOfflineLocations = false
    @State private var showInactive = false

    var body: some View {
        content
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { ProfileMenuView() .environmentObject(sessionManager) } }
            .task {
                await loadLocations()
            }
    }
}
private extension AccountDetailView {

    @ViewBuilder
    var content: some View {

        VStack(alignment: .leading, spacing: 16) {

            header

            if isUsingOfflineLocations {
                offlineLocationsBanner
            }

            if isLoading {
                ProgressView("Loading locations...")
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 30)
            }

            else if hasLoaded && locations.isEmpty {
                emptyState
            }

            else {
                locationList
            }

            Spacer()
        }
        .padding()
    }
}
private extension AccountDetailView {

    var header: some View {

        VStack(alignment: .leading, spacing: 12) {

            HStack {
                Spacer()
                accountImage
                Spacer()
            }
            .padding(.top, 8)

            Text("Locations")
                .font(.title.bold())
            
            Text("Account: \(account.name)")
                .font(.headline)
                .foregroundStyle(.secondary)

            Toggle(isOn: $showInactive) {
                Text("Show Inactive Locations")
                    .font(.subheadline)
            }
            .padding(.top, 4)
        }
    }

    var offlineLocationsBanner: some View {
        Label(
            offlineLocationsText,
            systemImage: "wifi.slash"
        )
        .font(.subheadline.weight(.medium))
        .foregroundStyle(.orange)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.orange.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    var offlineLocationsText: String {
        guard let cachedAt = offlineNavigationStore.cachedLocationsAt(for: account.id) else {
            return "Using saved locations from this device"
        }

        return "Using saved locations from \(formattedCacheDate(cachedAt))"
    }

    func formattedCacheDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
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
private extension AccountDetailView {

    var emptyState: some View {

        VStack(spacing: 8) {

            Image(systemName: "location.slash")
                .font(.system(size: 28))
                .foregroundStyle(.gray)

            Text("No locations available")
                .font(.headline)

            Text("Please configure locations on the web dashboard.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }
}


private extension AccountDetailView {

    var locationList: some View {

        ScrollView {

            LazyVStack(spacing: 12) {

                ForEach(filteredLocations) { location in

                    NavigationLink {
                        LocationDetailView(
                            locationId: location.id,
                            account: account,
                            locationName: location.name
                        )
                    } label: {

                        LocationCard(location: location)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 8)
        }
    }
}

private extension AccountDetailView {

    func loadLocations() async {

        isLoading = true
        hasLoaded = false

        defer {
            isLoading = false
            hasLoaded = true
        }

        do {
            locations = try await LocationApi.shared.getLocationsForAccount(
                accountId: account.id
            )
            offlineNavigationStore.cacheLocations(locations, accountId: account.id)
            isUsingOfflineLocations = false
        } catch {
            print("❌ Failed to load locations:", error)

            let cachedLocations = offlineNavigationStore.cachedLocations(for: account.id)
            if cachedLocations.isEmpty {
                locations = []
                isUsingOfflineLocations = false
            } else {
                locations = cachedLocations
                isUsingOfflineLocations = true
            }
        }
    }
}

private extension AccountDetailView {

    var filteredLocations: [Location] {
        if showInactive {
            return locations
        } else {
            return locations.filter { $0.active }
        }
    }
}

private struct LocationCard: View {

    let location: Location

    var body: some View {

        HStack(spacing: 14) {

            // Left status indicator
            Circle()
                .fill(location.active ? .green : .gray.opacity(0.4))
                .frame(width: 10, height: 10)

            // Content
            VStack(alignment: .leading, spacing: 4) {

                Text(location.name)
                    .font(.title.bold())

            }

            Spacer()

            // Optional subtle indicator (NOT system chevron)
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
