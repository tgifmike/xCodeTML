//
//import SwiftUI
//
//struct LocationStationsView: View {
//    
//    let locationId: String
//    let userId: String
//    
//    @State private var stations: [Station] = []
//    @State private var selectedStations: Set<String> = []
//    @State private var isLoading = true
//    @State private var errorMessage: String?
//    @State private var creatingLineCheck = false
//    @State private var createdLineCheckId: String?
//    @State private var showSuccess = false
// //   @State private var selectionMode: SelectionMode = .none
//    
//    var body: some View {
//        VStack(alignment: .leading, spacing: 16) {
//            
//            // Loading
//            if isLoading {
//                ProgressView("Loading stations...")
//            }
//            
//            // Error
//            else if let errorMessage {
//                Text("Error: \(errorMessage)")
//                    .foregroundColor(.red)
//            }
//            
//            // Empty
//            else if stations.isEmpty {
//                Text("No stations found for this location.\nPlease create stations on the website.")
//                    .foregroundColor(.red)
//            }
//            
//            // Content
//            else {
//                
//                Text("Select Stations:")
//                    .font(.title2)
//                    //.bold()
//                
////                HStack {
////                    Button("Select All") {
////                        selectedStations = Set(stations.compactMap { $0.id })
////                    }
////                    Spacer()
////
////                    Button("Deselect All") {
////                        selectedStations.removeAll()
////                    }
////                }
//                HStack {
//                    Button("Select All") {
//                                           selectedStations = Set(stations.compactMap { $0.id })
//                                       }
//
//                    Spacer()
//
//                        Button("Deselect All") {
//                                               selectedStations.removeAll()
//                                            }
//                }
//                .font(.subheadline)
//                .foregroundStyle(.blue)
//                .padding(.horizontal)
//                
////                enum SelectionMode: String, CaseIterable, Identifiable {
////                    case all = "Select All"
////                    case none = "None"
////
////                    var id: String { rawValue }
////                }
////
////                Picker("Selection", selection: $selectionMode) {
////                    ForEach(SelectionMode.allCases) { mode in
////                        Text(mode.rawValue).tag(mode)
////                    }
////                }
////                .pickerStyle(.segmented)
////                .padding(.horizontal)
////                .onChange(of: selectionMode) { _, newValue in
////                    switch newValue {
////                    case .all:
////                        selectedStations = Set(stations.compactMap { $0.id })
////                    case .none:
////                        selectedStations.removeAll()
////                    }
////                }
//                
//                ScrollView(.horizontal, showsIndicators: false) {
//                    HStack(spacing: 12) {
//                        ForEach(stations) { station in
//                            
//                            StationChip(
//                                title: station.stationName,
//                                isSelected: selectedStations.contains(station.id)
//                            ) {
//                                toggleSelection(station.id)
//                            }
//                        }
//                    }
//                }
//                
//                Text("Selected: \(selectedStations.count)")
//                    .foregroundColor(.secondary)
//                
//                Spacer().frame(height: 16)
//
//                Button {
//                    Task {
//                        await createLineCheck()
//                    }
//                } label: {
//                    if creatingLineCheck {
//                        ProgressView()
//                    } else {
//                        Text("Create Line Check")
//                            .frame(maxWidth: .infinity)
//                    }
//                }
//                .buttonStyle(.borderedProminent)
//                .disabled(selectedStations.isEmpty || creatingLineCheck)
//                .alert("Line Check Created!", isPresented: $showSuccess) {
//                    Button("OK", role: .cancel) {}
//                }
//            }
//                
//            
//            Spacer()
//        }
//        .padding()
//        .task {
//            await loadStations()
//        }
//    }
//    
//    private func toggleSelection(_ id: String) {
//        if selectedStations.contains(id) {
//            selectedStations.remove(id)
//        } else {
//            selectedStations.insert(id)
//        }
//    }
//    
//    private func loadStations() async {
//        isLoading = true
//        errorMessage = nil
//        
//        do {
//            stations = try await StationApi.getStationsByLocation(locationId: locationId)
//        } catch {
//            errorMessage = error.localizedDescription
//        }
//        
//        isLoading = false
//    }
//    
//    private func createLineCheck() async {
//
//        creatingLineCheck = true
//        errorMessage = nil
//
//        do {
//            let response = try await LineCheckApi.createLineCheck(
//                userId: userId,
//                stationIds: Array(selectedStations)
//            )
//
//            print("✅ Line Check Created:", response.id)
//
//            createdLineCheckId = response.id
//            showSuccess = true
//            // clear selection (same as Android)
//            selectedStations.removeAll()
//
//        } catch {
//            errorMessage = "Failed to create line check: \(error.localizedDescription)"
//        }
//
//        creatingLineCheck = false
//    }
//}

import SwiftUI

struct LocationStationsView: View {

    let locationId: String
    let userId: String
    let locationName: String

    // MARK: - State

    @State private var stations: [Station] = []
    @State private var selectedStations: Set<String> = []

    @State private var isLoading = true
    @State private var errorMessage: String?

    @State private var creatingLineCheck = false

    /// Navigation trigger
    @State private var createdLineCheckId: String?

    // MARK: - Body

    var body: some View {

        NavigationStack {

            content
                //.navigationTitle("Stations for \(locationName)")
                .navigationBarTitleDisplayMode(.inline)
                .navigationDestination(item: $createdLineCheckId) { id in
                    LineCheckDetailView(
                        lineCheckId: id,
                        locationId: locationId
                    )
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

    var stationSelectionUI: some View {

        VStack(alignment: .leading, spacing: 12) {
            
            Text("Stations for \(locationName)")
                .font(.title)
                .padding(.horizontal)
                .foregroundStyle(Color(Color.blue))

            Text("Select Stations:")
                .font(.title2.weight(.semibold))

            // Select controls
            HStack {
                Button("Select All") {
                    selectedStations = Set(stations.map(\.id))
                }

                Spacer()

                Button("Clear") {
                    selectedStations.removeAll()
                }
            }
            .font(.subheadline)
            .foregroundStyle(.blue)

            // Chips
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
                .font(.caption)
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
                }
            }
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(selectedStations.isEmpty || creatingLineCheck)
        .padding(.top, 8)
    }
}

private extension LocationStationsView {

    func toggleSelection(_ id: String) {
        if selectedStations.contains(id) {
            selectedStations.remove(id)
        } else {
            selectedStations.insert(id)
        }
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
}

private extension LocationStationsView {

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

            // 🚀 Navigation happens automatically
            createdLineCheckId = response.id

        } catch {
            errorMessage = "Failed to create line check: \(error.localizedDescription)"
        }

        creatingLineCheck = false
    }
}
