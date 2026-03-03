import SwiftUI
import Foundation
import SwiftUI


// MARK: - LineCheckDetailView

struct LineCheckDetailView: View {
    let lineCheckId: String
    let locationId: String
    
    @State private var lineCheck: LineCheckDto?
    @State private var stations: [LineCheckStationInput] = []
    @State private var isLoading = true
    @State private var error: String?
    @State private var isSaving = false
    @State private var saveError: String?
    @State private var saveSuccess = false
    @State private var originalStations: [LineCheckStationInput] = []
    
    private var hasChanges: Bool {
        stations != originalStations
    }
    
    @FocusState private var focusedField: LineCheckField?
    
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
                            headerSection(lineCheck: lineCheck)
                            
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
    
    // MARK: Header
    private func headerSection(lineCheck: LineCheckDto) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Conducted By: \(lineCheck.username ?? "Unknown")")
                .font(.headline)
            Text("Line Check ID: \(lineCheck.id)")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text("Location ID: \(locationId)")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
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
            // ✅ Real API Call
            let response = try await LineCheckApi.getLineCheckById(
                lineCheckId: lineCheckId
            )
            
            // Store raw DTO
            lineCheck = response
            
            // ✅ Map DTO → Editable UI State
            stations = response.stations.compactMap { stationDto in
                
                guard let stationUUID = UUID(uuidString: stationDto.id)
                else { return nil }
                
                originalStations = stations
                
                let mappedItems: [LineCheckItemInput] = stationDto.items.compactMap { dto in
                    guard let idString = dto.id,
                          let uuid = UUID(uuidString: idString)
                    else { return nil }
                    
                    return LineCheckItemInput(id: uuid, item: dto)
                }
                
                return LineCheckStationInput(
                    id: stationUUID,
                    stationName: stationDto.stationName ?? "Unnamed Station",
                    items: mappedItems
                )
            }
            
        } catch {
            self.error = error.localizedDescription
        }
        
        isLoading = false
    }
    
    private func saveLineCheck() async {
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
                        
                        dto.itemChecked = itemInput.isChecked
                        dto.observations = itemInput.observations
                        
                        return dto
                    }
                )
            }
            
            // ✅ API Call
            _ = try await LineCheckApi.saveLineCheck(currentLineCheck)
            
            saveSuccess = true
            
        } catch {
            saveError = error.localizedDescription
        }
        
        isSaving = false
    }
}


// MARK: - Preview
struct LineCheckDetailView_Previews: PreviewProvider {
    static var previews: some View {
        LineCheckDetailView(lineCheckId: "1234", locationId: "5678")
    }
}

