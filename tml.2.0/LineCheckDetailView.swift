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
            print("Save tapped")
            // TODO: Map items to payload & call API
        } label: {
            Text("Save Line Check")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .padding(.top, 8)
    }

    // MARK: Load Data
    private func loadLineCheck() async {
        isLoading = true
        defer { isLoading = false }

        do {
            // Simulate network delay
            try await Task.sleep(nanoseconds: 1_000_000_000)

            // Dummy data
            let dummyItems = [
                LineCheckItemDto(
                    id: UUID().uuidString,
                    itemName: "Item A",
                    shelfLife: "3 days",
                    templateNotes: "Check carefully",
                    tempTaken: true,
                    checkMark: false,
                    panSize: "12x12",
                    tool: true,
                    toolName: "Spatula",
                    portioned: true,
                    portionSize: "1 cup",
                    itemChecked: false,
                    temperature: nil,
                    minTemp: 35,
                    maxTemp: 45,
                    observations: nil
                ),
                LineCheckItemDto(
                    id: UUID().uuidString,
                    itemName: "Item B",
                    shelfLife: "3 days",
                    templateNotes: "Check carefully",
                    tempTaken: false,
                    checkMark: true,
                    panSize: "12x12",
                    tool: true,
                    toolName: "Spatula",
                    portioned: true,
                    portionSize: "1 cup",
                    itemChecked: false,
                    temperature: nil,
                    minTemp: 35,
                    maxTemp: 45,
                    observations: nil
                )
            ]

            let dummyStations = [
                LineCheckStationDto(
                    id: UUID().uuidString,
                    stationName: "Station 1",
                    items: dummyItems
                ),
                LineCheckStationDto(
                    id: UUID().uuidString,
                    stationName: "Station 2",
                    items: dummyItems
                )
            ]

            let dummyLineCheck = LineCheckDto(
                id: lineCheckId,
                username: "Test User",
                stations: dummyStations
            )

            lineCheck = dummyLineCheck

            // Map to editable items safely
            stations = dummyLineCheck.stations.compactMap { stationDto in
                
                guard let stationUUID = UUID(uuidString: stationDto.id) else { return nil }
                
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
    }
}



// MARK: - Preview
struct LineCheckDetailView_Previews: PreviewProvider {
    static var previews: some View {
        LineCheckDetailView(lineCheckId: "1234", locationId: "5678")
    }
}

