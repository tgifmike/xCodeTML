import SwiftUI
import GoogleSignIn

struct LocationStationsView: View {

    let locationId: String
    let userId: String
    let locationName: String
    let accountName: String

    let session: UserSession
    let onLogout: () -> Void

    // MARK: - State

    @State private var stations: [Station] = []
    @State private var selectedStations: Set<String> = []

    @State private var isLoading = true
    @State private var errorMessage: String?

    @State private var creatingLineCheck = false
    @State private var createdLineCheckId: String?

    var body: some View {

        NavigationStack {

            content
                .navigationBarTitleDisplayMode(.inline)
                .navigationDestination(item: $createdLineCheckId) { id in
                    LineCheckDetailView(
                        lineCheckId: id,
                        locationId: locationId,
                        locationName: locationName,
                        accountName: accountName
                    )
                }
                .toolbar {
                    toolbarContent
                }
        }
        .task {
            await loadStations()
        }
    }
}

private extension LocationStationsView {

    var content: some View {

        VStack(alignment: .leading, spacing: 16) {

            if isLoading {
                ProgressView("Loading stations...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            else if let errorMessage {
                ContentUnavailableView(
                    "Error",
                    systemImage: "exclamationmark.triangle",
                    description: Text(errorMessage)
                )
            }

            else if stations.isEmpty {
                ContentUnavailableView(
                    "No Stations",
                    systemImage: "tray",
                    description: Text("Create stations on the website.")
                )
            }

            else {
                stationSelectionUI
                createButton
            }

            Spacer()
        }
        .padding()
    }
}

private extension LocationStationsView {

    var toolbarContent: some ToolbarContent {

        ToolbarItem(placement: .topBarTrailing) {

            Menu {

                Button(role: .destructive) {
                    signOut()
                } label: {
                    Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                }

            } label: {

                // PROFILE IMAGE
                Group {
                    if let imageUrl = session.userImage,
                       let url = URL(string: imageUrl) {

                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .scaledToFill()
                        } placeholder: {
                            ProgressView()
                        }

                    } else {
                        Image(systemName: "person.crop.circle.fill")
                            .resizable()
                            .foregroundStyle(.gray)
                    }
                }
                .frame(width: 34, height: 34)
                .clipShape(Circle())
            }
        }
    }
}

private extension LocationStationsView {

    var stationSelectionUI: some View {

        VStack(alignment: .leading, spacing: 12) {

            Text("Stations for \(locationName)")
                .font(.title)
                .foregroundStyle(.blue)

            Text("Select Stations:")
                .font(.title2.weight(.semibold))

            HStack {
                Button("Select All") {
                    selectedStations = Set(stations.map(\.id))
                }

                Spacer()

                Button("Clear All") {
                    selectedStations.removeAll()
                }
            }
            .font(.subheadline)
            .foregroundStyle(.blue)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(stations) { station in
                        StationChip(
                            title: station.stationName,
                            isSelected: selectedStations.contains(station.id)
                        ) {
                            toggleSelection(station.id)
                        }
                    }
                }
            }

            Text("\(selectedStations.count) Selected")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

private extension LocationStationsView {

    var createButton: some View {

        Button {
            Task { await createLineCheck() }
        } label: {
            ZStack {
                if creatingLineCheck {
                    ProgressView()
                } else {
                    Text("Create Line Check")
                        .frame(maxWidth: .infinity)
                        .font(.headline.bold())
                }
            }
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(selectedStations.isEmpty || creatingLineCheck)
    }
}

private extension LocationStationsView {

    func signOut() {
        GIDSignIn.sharedInstance.signOut()
        onLogout()
    }
}
// MARK: - Actions / API

private extension LocationStationsView {

    func loadStations() async {

        isLoading = true
        errorMessage = nil

        do {
            stations = try await StationApi.getStationsByLocation(
                locationId: locationId
            )
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func toggleSelection(_ id: String) {

        if selectedStations.contains(id) {
            selectedStations.remove(id)
        } else {
            selectedStations.insert(id)
        }
    }

    func createLineCheck() async {

        creatingLineCheck = true
        errorMessage = nil

        do {
            let response = try await LineCheckApi.createLineCheck(
                userId: userId,
                stationIds: Array(selectedStations)
            )

            print("✅ Line Check Created:", response.id)

            selectedStations.removeAll()
            createdLineCheckId = response.id

        } catch {
            errorMessage = "Failed to create line check: \(error.localizedDescription)"
        }

        creatingLineCheck = false
    }
}
