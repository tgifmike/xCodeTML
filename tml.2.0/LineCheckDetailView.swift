import SwiftUI
import Foundation
import SwiftUI


// MARK: - LineCheckDetailView

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
    @State private var startTime = Date()
    
    private var hasChanges: Bool {
        stations != originalStations
    }
    
    @FocusState private var focusedField: LineCheckField?
    
    @Environment(\.dismiss) private var dismiss
    
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
                        VStack(spacing: 16) {
                            headerSection(lineCheck: lineCheck, accountName: accountName, locationName: locationName)
                            
                            ForEach($stations) { $station in
                                LineCheckStationSection(
                                    stationName: station.stationName,
                                    items: $station.items,
                                    focusedField: $focusedField
                                )
                            }
                            
                            saveButton
                        }
                        .padding()
                        .padding(.bottom, 150)
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
        .alert("Save Failed", isPresented: Binding(
            get: { saveError != nil },
            set: { _ in saveError = nil }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(saveError ?? "")
        }
        .alert("Success", isPresented: $saveSuccess) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Line Check saved successfully.")
        }
    }
    
    private var startTimeString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: Date())
    }
    
    private func headerSection(
        lineCheck: LineCheckDto,
        accountName: String,
        locationName: String
    ) -> some View {

    
    

        VStack(spacing: 14) {

            // ROW 1
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

            // ROW 2
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
        .shadow(color: .black.opacity(0.50), radius: 3, y: 2)
    }
    
    // MARK: Save Button
    private var saveButton: some View {
        Button {
            Task {
                await saveLineCheck()
            }
        } label: {
            if isSaving {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else {
                Text("Save Line Check")
                    .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(.borderedProminent)
        .disabled(isSaving || !hasChanges)
        .padding(.top, 8)
    }
    
    // MARK: Load Data
    private func loadLineCheck() async {
        isLoading = true
        error = nil

        do {
            // ✅ Fetch line check from API
            let response = try await LineCheckApi.getLineCheckById(lineCheckId: lineCheckId)
            lineCheck = response
            
            // ✅ Map DTO → Editable UI State
            var mappedStations: [LineCheckStationInput] = []

            for stationDto in response.stations {
                // Convert station ID string to UUID (fallback to new UUID if invalid)
                let stationUUID = UUID(uuidString: stationDto.id) ?? UUID()

                // Map items
                let mappedItems: [LineCheckItemInput] = stationDto.items.map { dto in
                    let itemUUID = UUID(uuidString: dto.id ?? "") ?? UUID()
                    
                    return LineCheckItemInput(
                        id: itemUUID,
                        item: dto,
                        temperature: dto.temperature != nil ? "\(dto.temperature!)" : "",
                        observations: dto.observations ?? "",
                        isChecked: nil,    // existing Yes/No
                        isMissing: false               // default for new "missing" checkbox
                    )
                }

                let stationInput = LineCheckStationInput(
                    id: stationUUID,
                    //stationName: stationDto.stationName ?? "Unnamed Station",
                    stationName: stationDto.stationName?.isEmpty == false
                            ? stationDto.stationName!
                            : "Unnamed Station",
                    items: mappedItems
                )

                mappedStations.append(stationInput)
            }

            stations = mappedStations
            originalStations = mappedStations

        } catch let err {
            error = err.localizedDescription
        }

        isLoading = false
    }
    
    private func saveLineCheck() async {
        
        let requiredItems = stations
            .flatMap { $0.items }
            .filter { $0.item.checkMark }

        guard requiredItems.allSatisfy({ $0.isChecked != nil }) else {
            saveError = "All required items must be marked Yes or No."
            return
        }
        
        guard var currentLineCheck = lineCheck else { return }
        
        isSaving = true
        saveError = nil
        
        do {
            // ✅ Map editable stations back into DTO format
            currentLineCheck.stations = stations.map { stationInput in
                
                LineCheckStationDto(
                    id: stationInput.id.uuidString,
                    stationName: stationInput.stationName,
                    items: stationInput.items.map { itemInput in
                        
                        var dto = itemInput.item
                        
                        // Update mutable values from UI
                        dto.temperature = itemInput.temperature.isEmpty
                            ? nil
                            : Float(itemInput.temperature)
                        
                        dto.itemChecked = itemInput.isChecked ?? false
                        dto.observations = itemInput.observations
                        
                        
                        
                        return dto
                    }
                )
            }
            
            // ✅ API Call
            _ = try await LineCheckApi.saveLineCheck(currentLineCheck)
            
            saveSuccess = true
            // ✅ Go back after success
                    dismiss()
            
        } catch {
            saveError = error.localizedDescription
        }
        
        isSaving = false
    }
}




