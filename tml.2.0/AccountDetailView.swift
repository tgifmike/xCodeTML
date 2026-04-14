import SwiftUI
import GoogleSignIn

struct AccountDetailView: View {

    @EnvironmentObject var sessionManager: SessionManager

//    let accountId: String
//    let accountName: String
    
    let account: Account

    @State private var locations: [Location] = []
    @State private var isLoading = false
    @State private var hasLoaded = false
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
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Toggle(isOn: $showInactive) {
                Text("Show Inactive Locations")
                    .font(.subheadline)
            }
            .padding(.top, 4)
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

        List(filteredLocations) { location in

            NavigationLink {

                LocationDetailView(
                    locationId: location.id,
                    account: account,
                    locationName: location.name
                )

            } label: {

                HStack(spacing: 12) {

                    VStack(alignment: .leading, spacing: 2) {

                        Text(location.name)
                            .font(.body.weight(.medium))

                        Text(location.active ? "Active" : "Inactive")
                            .font(.caption)
                            .foregroundStyle(location.active ? .green : .secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
            }
        }
        .listStyle(.plain)
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

        locations = await LocationApi.shared.getLocationsForAccount(
            accountId: account.id
        )
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
