
import SwiftUI
import Foundation

struct LineCheckDetailView: View {
    let lineCheckId: String
    let locationId: String
    let locationName: String
    let accountName: String
    
    @State private var lineCheck: LineCheckDto?
    @State private var stations: [LineCheckStationInput] = []
    @State private var isLoading = true
    @State private var error: String?
    @State private var isSaving = false
    @State private var saveError: String?
    @State private var saveSuccess = false
    @State private var originalStations: [LineCheckStationInput] = []
    
    @FocusState private var focusedField: LineCheckField?
    @Environment(\.dismiss) private var dismiss
    
    private var hasChanges: Bool { stations != originalStations }
    
    private var totalItems: Int { stations.flatMap { $0.items }.count }
    private var completedItems: Int { stations.flatMap { $0.items }.filter { !$0.temperature.isEmpty || $0.isMissing || $0.isChecked != nil }.count }
    private var progress: Double { totalItems > 0 ? Double(completedItems) / Double(totalItems) : 0 }
    private var progressColor: Color { progress == 1 ? .green : progress > 0.7 ? .orange : .red }
    
    private var startTimeString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: Date())
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error {
                    Text("Error: \(error)")
                        .foregroundColor(.red)
                        .padding()
                } else if let lineCheck {
                    ScrollView {
                        LazyVStack(spacing: 8, pinnedViews: [.sectionHeaders]) {

                            Section(header: progressSection) {

                                headerSection(
                                    lineCheck: lineCheck,
                                    accountName: accountName,
                                    locationName: locationName
                                )

                                ForEach($stations) { $station in
                                    LineCheckStationSection(
                                        stationName: station.stationName,
                                        items: $station.items,
                                        focusedField: $focusedField
                                    )
                                }

                                saveButton
                                    .padding(.top, 8)
                                    .padding(.bottom, 16)
                            }
                        }
                        .padding(.horizontal)
                        .safeAreaInset(edge: .bottom) {
                            Color.clear.frame(height: 40)
                        }
                    }
                    .scrollDismissesKeyboard(.interactively)
                } else {
                    Text("No data available")
                        .padding()
                }
            }
            .navigationTitle("Line Check")
            .navigationBarTitleDisplayMode(.inline)
        }
        .task { await loadLineCheck() }
        .alert("Save Failed", isPresented: Binding(get: { saveError != nil }, set: { _ in saveError = nil })) {
            Button("OK", role: .cancel) {}
        } message: { Text(saveError ?? "") }
        .alert("Success", isPresented: $saveSuccess) {
            Button("OK", role: .cancel) {}
        } message: { Text("Line Check saved successfully.") }
    }
    
    // MARK: Header
    private func headerSection(lineCheck: LineCheckDto, accountName: String, locationName: String) -> some View {
        VStack(spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Conducted By", systemImage: "person.fill")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    Text(lineCheck.username ?? "Unknown")
                        .font(.headline)
                        .foregroundColor(.blue)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Label("Start Time", systemImage: "clock.fill")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    Text(startTimeString)
                        .font(.headline)
                        .foregroundColor(.blue)
                }
            }
            
            Divider()
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Account Name", systemImage: "building.2.fill")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    Text(accountName)
                        .font(.headline)
                        .foregroundColor(.blue)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Label("Location Name", systemImage: "mappin.and.ellipse")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    Text(locationName)
                        .font(.headline)
                        .foregroundColor(.blue)
                }
            }
        }
        .padding()
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.5), radius: 3, y: 2)
    }
    
    // MARK: Progress Section
    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Progress").font(.headline)
                Spacer()
                Text("\(completedItems) / \(totalItems) Completed")
                    .font(.subheadline)
                    .foregroundColor(.blue)
            }
            ProgressView(value: progress)
                .progressViewStyle(.linear)
                .tint(progressColor)
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.1), radius: 3, y: 2)
    }
    
    // MARK: Save Button
    private var saveButton: some View {
        Button {
            Task { await saveLineCheck() }
        } label: {
            if isSaving {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else {
                Text("Save Line Check")
                    .frame(maxWidth: .infinity)
                    .font(.headline.bold())
            }
        }
        .buttonStyle(.borderedProminent)
        .disabled(isSaving || !hasChanges)
    }
    
    // MARK: Load Line Check
    private func loadLineCheck() async {
        isLoading = true
        error = nil
        do {
            let response = try await LineCheckApi.getLineCheckById(lineCheckId: lineCheckId)
            lineCheck = response
            
            stations = response.stations.map { stationDto in
                let stationUUID = UUID(uuidString: stationDto.id) ?? UUID()
                let items = stationDto.items.map { itemDto -> LineCheckItemInput in
                    let itemUUID = UUID(uuidString: itemDto.id ?? "") ?? UUID()
                    return LineCheckItemInput(
                        id: itemUUID,
                        item: itemDto,
                        temperature: itemDto.temperature != nil ? "\(itemDto.temperature!)" : "",
                        observations: itemDto.observations ?? "",
                        isChecked: nil,
                        isMissing: itemDto.isMissing ?? false
                    )
                }
                return LineCheckStationInput(
                    id: stationUUID,
                    stationName: stationDto.stationName?.isEmpty == false ? stationDto.stationName! : "Unnamed Station",
                    items: items
                )
            }
            originalStations = stations
        } catch let err {
            self.error = err.localizedDescription
        }
        isLoading = false
    }
    
    // MARK: Save Line Check
    private func saveLineCheck() async {
        let requiredItems = stations
            .flatMap { $0.items }
            .filter { $0.item.checkMark && !$0.isMissing && !$0.item.tempTaken }

        guard requiredItems.allSatisfy({ $0.isChecked != nil }) else {
            saveError = "All item need to be temped, checked or marked missing."
            return
        }
        guard var currentLineCheck = lineCheck else { return }
        isSaving = true
        saveError = nil
        do {
            currentLineCheck.stations = stations.map { stationInput in
                LineCheckStationDto(
                    id: stationInput.id.uuidString,
                    stationName: stationInput.stationName,
                    items: stationInput.items.map { itemInput in
                        var dto = itemInput.item
//                        dto.temperature = itemInput.temperature.isEmpty ? nil : Float(itemInput.temperature)
//                        dto.itemChecked = itemInput.isChecked ?? false
//                        dto.observations = itemInput.observations
                        dto.isMissing = itemInput.isMissing

                        if itemInput.isMissing {
                            dto.temperature = nil
                            dto.itemChecked = nil   // Use nil instead of false
                        } else if itemInput.item.tempTaken {
                            dto.temperature = itemInput.temperature.isEmpty ? nil : Float(itemInput.temperature)
                            dto.itemChecked = nil
                        } else {
                            dto.itemChecked = itemInput.isChecked
                            dto.temperature = nil
                        }

                        dto.observations = itemInput.observations
                        return dto
                    }
                )
            }
            _ = try await LineCheckApi.saveLineCheck(currentLineCheck)
            saveSuccess = true
            dismiss()
        } catch {
            saveError = error.localizedDescription
        }
        isSaving = false
    }
}

