import SwiftUI
import GoogleSignIn

struct LocationStationsView: View {

    let locationId: String
    let locationName: String
//    let accountName: String
    let account: Account

    @EnvironmentObject var sessionManager: SessionManager

    @State private var stations: [Station] = []
    @State private var selectedStations: Set<String> = []

    @State private var isLoading = true
    @State private var errorMessage: String?

    @State private var creatingLineCheck = false
    @State private var createdLineCheckId: String?

    var body: some View {

        NavigationStack {

            content
                .navigationTitle("")
                .navigationBarTitleDisplayMode(.inline)
                .navigationDestination(item: $createdLineCheckId) { id in
                    LineCheckDetailView(
                        lineCheckId: id,
                        locationId: locationId,
                        locationName: locationName,
                        accountName: account.name
                    )
                }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        ProfileMenuView()
                            .environmentObject(sessionManager)
                    }
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

            header

            if isLoading {
                ProgressView("Loading stations...")
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 20)
            }

            else if let errorMessage {
                errorView
            }

            else if stations.isEmpty {
                emptyView
            }

            else {
                stationContent
            }

            Spacer()
        }
        .padding()
    }
}

private extension LocationStationsView {

    var header: some View {

        VStack(alignment: .leading, spacing: 12) {
            
            HStack {
                Spacer()
                accountImage
                Spacer()
            }
            .padding(.top, 8)

            Text(locationName)
                .font(.title.bold())

            Text("Account: \(account.name)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("Select stations to include in this line check")
                .font(.callout)
                .foregroundStyle(.primary)
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

private extension LocationStationsView {

    var errorView: some View {

        ContentUnavailableView(
            "Error",
            systemImage: "exclamationmark.triangle",
            description: Text(errorMessage ?? "Unknown error")
        )
    }
}

private extension LocationStationsView {

    var emptyView: some View {

        ContentUnavailableView(
            "No Stations",
            systemImage: "tray",
            description: Text("Create stations on the web dashboard.")
        )
    }
}

private extension LocationStationsView {

    var stationContent: some View {

        VStack(alignment: .leading, spacing: 16) {

            actionRow

            stationList

            footer

            createButton
        }
    }
}

//private extension LocationStationsView {
//
//    var actionRow: some View {
//
//        HStack {
//
//            Button("Select All") {
//                selectedStations = Set(stations.map(\.id))
//            }
//
//            Spacer()
//
//            Button("Clear") {
//                selectedStations.removeAll()
//            }
//        }
//        .font(.subheadline)
//        .foregroundStyle(.blue)
//    }
//}

private extension LocationStationsView {

    var actionRow: some View {

        HStack {

            Text("Stations")
                .font(.headline)

            Spacer()

//            Menu {

                Button("Select All") {
                    selectedStations = Set(stations.map(\.id))
                }

//                Button("Clear Selection", role: .destructive) {
//                    selectedStations.removeAll()
//                }

//            } label: {
//                Image(systemName: "ellipsis.circle")
//                    .font(.title3)
//            }
        }
        .padding(.horizontal, 4)
    }
}

//private extension LocationStationsView {
//
//    var stationList: some View {
//
//        ScrollView(.horizontal, showsIndicators: false) {
//
//            HStack(spacing: 12) {
//
//                ForEach(stations) { station in
//
//                    StationChip(
//                        title: station.stationName,
//                        isSelected: selectedStations.contains(station.id)
//                    ) {
//                        toggleSelection(station.id)
//                    }
//                }
//            }
//        }
//    }
//}

private extension LocationStationsView {

    var stationList: some View {

        LazyVGrid(
            columns: [
                GridItem(.adaptive(minimum: 140), spacing: 12)
            ],
            spacing: 12
        ) {

            ForEach(stations) { station in

                StationCard(
                    station: station,
                    isSelected: selectedStations.contains(station.id)
                ) {
                    toggleSelection(station.id)
                }
            }
        }
    }
}

struct StationCard: View {

    let station: Station
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {

        Button(action: onTap) {

            VStack(alignment: .leading, spacing: 8) {

                HStack {
                    Text(station.stationName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)

                    Spacer()

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }

                Text(isSelected ? "Selected" : "Tap to select")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.blue.opacity(0.12) : Color.gray.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

//private extension LocationStationsView {
//
//    var footer: some View {
//
//        Text("\(selectedStations.count) selected")
//            .font(.caption)
//            .foregroundStyle(.secondary)
//    }
//}

private extension LocationStationsView {

    var footer: some View {

        VStack(spacing: 10) {

            Divider()

            HStack {

                Text("\(selectedStations.count) selected")
                    .font(.subheadline.weight(.medium))

                Spacer()

                Button("Clear") {
                    selectedStations.removeAll()
                }
                .font(.subheadline)
                .foregroundStyle(.red)
                .disabled(selectedStations.isEmpty)
            }
        }
        .padding(.top, 8)
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
                        .font(.headline)
                }
            }
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(selectedStations.isEmpty || creatingLineCheck)
    }
}
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
                userId: sessionManager.session?.userId ?? "",
                stationIds: Array(selectedStations)
            )

            selectedStations.removeAll()
            createdLineCheckId = response.id

        } catch {
            errorMessage = error.localizedDescription
        }

        creatingLineCheck = false
    }
}
