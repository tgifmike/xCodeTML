import SwiftUI
import GoogleSignIn

struct LocationStationsView: View {

    let locationId: String
    let locationName: String
//    let accountName: String
    let account: Account

    @EnvironmentObject var sessionManager: SessionManager
    @EnvironmentObject var offlineSyncCoordinator: OfflineSyncCoordinator
    @Environment(\.dismiss) private var dismiss

    @StateObject private var templateStore = OfflineLineCheckTemplateStore.shared
    @StateObject private var pinStore = OfflinePinDeviceStore.shared
    @State private var stations: [Station] = []
    @State private var selectedStations: Set<String> = []

    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var isUsingOfflineStations = false

    @State private var creatingLineCheck = false
    @State private var createdLineCheck: LineCheckDto?

    var body: some View {
        content
            .navigationTitle("Select Stations")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: createdLineCheckBinding) {
                if let lineCheck = createdLineCheck {
                    LineCheckDetailView(
                        lineCheckId: lineCheck.id,
                        locationId: locationId,
                        locationName: locationName,
                        accountName: account.name,
                        initialLineCheck: lineCheck,
                        onComplete: {
                            createdLineCheck = nil

                            Task { @MainActor in
                                try? await Task.sleep(nanoseconds: 150_000_000)
                                dismiss()
                            }
                        }
                    )
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    ProfileMenuView(pinEnrollmentAccount: account)
                        .environmentObject(sessionManager)
                }
            }
            .task {
                await loadStations()
            }
    }
}

private extension LocationStationsView {

    var createdLineCheckBinding: Binding<Bool> {
        Binding(
            get: { createdLineCheck != nil },
            set: { isPresented in
                if !isPresented {
                    createdLineCheck = nil
                }
            }
        )
    }

    var content: some View {

        VStack(alignment: .leading, spacing: 16) {

            header

            if isLoading {
                ProgressView("Loading stations...")
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 20)
            }

            else if errorMessage != nil {
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

            if shouldShowOfflineStationsBanner {
                offlineBanner
            }

            stationList

            footer

            createButton
        }
    }
}

private extension LocationStationsView {

    var actionRow: some View {

        HStack {

            Text("Stations")
                .font(.headline)

            Spacer()


                Button("Select All") {
                    selectedStations = Set(stations.map(\.id))
                }

        }
        .padding(.horizontal, 4)
    }

    var shouldShowOfflineStationsBanner: Bool {
        isUsingOfflineStations && !offlineSyncCoordinator.isOnline
    }

    var offlineBanner: some View {
        Label(
            offlineCacheText,
            systemImage: "wifi.slash"
        )
        .font(.subheadline.weight(.medium))
        .foregroundStyle(.orange)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.orange.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    var offlineCacheText: String {
        guard let cachedAt = templateStore.cachedAt(for: locationId) else {
            return "Offline. Using saved station data from this device"
        }

        return "Offline. Using saved station data from \(formattedCacheDate(cachedAt))"
    }

    func formattedCacheDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}



private extension LocationStationsView {

    var stationList: some View {

        LazyVGrid(
            columns: [
                GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 12)
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

                HStack(alignment: .top, spacing: 8) {
                    Text(station.stationName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(stationNameLineLimit)
                        .minimumScaleFactor(0.72)
                        .allowsTightening(true)
                        .truncationMode(.tail)

                    Spacer()

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }

                Text(isSelected ? "Selected" : "Tap to select")
                    .font(.caption)
                    .foregroundStyle(.primary)
            }
            .padding()
            .frame(maxWidth: .infinity, minHeight: 78, maxHeight: 78, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        isSelected
                        ? Color.blue.opacity(0.15)
                        : Color(.secondarySystemBackground)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(
                        isSelected
                        ? Color.blue.opacity(0.8)
                        : Color.primary.opacity(0.06),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private var stationNameLineLimit: Int {
        station.stationName.contains(" ") ? 2 : 1
    }
}

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
                    Text(isUsingOfflineStations ? "Create Offline Line Check" : "Create Line Check")
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
        isUsingOfflineStations = false
        defer { isLoading = false }

        do {
            stations = try await StationApi.shared.getStationsByLocation(
                locationId: locationId
            )
            templateStore.cacheStations(stations, locationId: locationId)
        } catch {
            let cachedStations = templateStore.cachedStations(for: locationId)

            if shouldUseOfflineData(for: error), !cachedStations.isEmpty {
                stations = cachedStations
                isUsingOfflineStations = true
            } else {
                errorMessage = error.localizedDescription
            }
        }
    }

    var isPinSession: Bool {
        sessionManager.session?.authProvider == .pin
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

        let stationIds = Array(selectedStations)
        let userId = sessionManager.session?.userId ?? ""

        do {
            let response = try await LineCheckApi.shared.createLineCheck(
                userId: userId,
                stationIds: stationIds
            )

            templateStore.cacheTemplate(
                from: response,
                selectedStationIds: stationIds,
                availableStations: stations,
                locationId: locationId
            )
            selectedStations.removeAll()
            createdLineCheck = response

        } catch {
            if shouldUseOfflineData(for: error),
               let offlineLineCheck = templateStore.makeOfflineLineCheck(
                   locationId: locationId,
                   selectedStationIds: stationIds,
                   userId: userId,
                   username: sessionManager.session?.userName
               ) {
                OfflineLineCheckStore.shared.registerDraft(
                    lineCheck: offlineLineCheck,
                    locationId: locationId,
                    locationName: locationName,
                    accountName: account.name,
                    userId: userId,
                    stationIds: stationIds
                )
                selectedStations.removeAll()
                createdLineCheck = offlineLineCheck
            } else if shouldUseOfflineData(for: error) {
                errorMessage = "No saved template is available for the selected stations. Create this station set once while online, then it can be used offline."
            } else {
                errorMessage = error.localizedDescription
            }
        }

        creatingLineCheck = false
    }

    func shouldUseOfflineData(for error: Error) -> Bool {
        guard let urlError = error as? URLError else { return false }

        switch urlError.code {
        case .notConnectedToInternet,
             .networkConnectionLost,
             .cannotConnectToHost,
             .cannotFindHost,
             .dnsLookupFailed,
             .timedOut:
            return true
        default:
            return false
        }
    }
}
