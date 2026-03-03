//
//
//import SwiftUI
//
//struct LineCheckDetailView: View {
//
//    let lineCheckId: String
//    let locationId: String
//
//    var body: some View {
//        VStack(spacing: 20) {
//
//            Text("Line Check Detail")
//                .font(.largeTitle)
//                .fontWeight(.bold)
//
//            Text("Line Check ID:")
//                .font(.headline)
//
//            Text(lineCheckId)
//                .foregroundColor(.secondary)
//
//            Text("Location ID:")
//                .font(.headline)
//                .padding(.top)
//
//            Text(locationId)
//                .foregroundColor(.secondary)
//
//            Spacer()
//        }
//        .padding()
//        .navigationTitle("Line Check")
//        .navigationBarTitleDisplayMode(.inline)
//    }
//}

import SwiftUI
import Foundation
import SwiftUI

// MARK: - Models

//struct LineCheckDto: Identifiable {
//    let id: String
//    let username: String?
//    let stations: [LineCheckStationDto]
//}

//struct LineCheckStationDto: Identifiable {
//    let id: String
//    let stationName: String?
//    let items: [LineCheckItemDto]
//}

//struct LineCheckItemDto: Identifiable {
//    let id: String
//    let itemName: String?
//    let shelfLife: String?
//    let panSize: String?
//    let toolName: String?
//    let portionSize: String?
//    let templateNotes: String?
//    let tempTaken: Bool
//}

// Input model for editable state
//struct LineCheckItemInput: Identifiable {
//    let id: UUID
//    let item: LineCheckItemDto
//    var temperature: String = ""
//    var observations: String = ""
//}

// Focus state enum
//enum LineCheckField: Hashable {
//    case temperature(UUID)
//    case observation(UUID)
//}

// MARK: - LineCheckDetailView

struct LineCheckDetailView: View {
    let lineCheckId: String
    let locationId: String

    @State private var lineCheck: LineCheckDto?
    @State private var items: [LineCheckItemInput] = []
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

                            ForEach($items) { $item in
                                LineCheckItemRow(input: $item, focusedField: $focusedField)
                                    .id(item.id)
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
                ),
                LineCheckItemDto(
                    id: UUID().uuidString,
                    itemName: "Item A",
                    shelfLife: "3 days",
                    templateNotes: "Check carefully",
                    tempTaken: true,
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
                )
            ]

            let dummyLineCheck = LineCheckDto(
                id: lineCheckId,
                username: "Test User",
                stations: dummyStations
            )

            lineCheck = dummyLineCheck

            // Map to editable items safely
            items = dummyLineCheck.stations.flatMap { $0.items }.compactMap { dto in
                guard let idString = dto.id, let uuid = UUID(uuidString: idString) else { return nil }
                return LineCheckItemInput(id: uuid, item: dto)
            }

        } catch {
            self.error = error.localizedDescription
        }
    }
}

// MARK: - Item Row
//struct LineCheckItemRow: View {
//    @Binding var input: LineCheckItemInput
//    @FocusState.Binding var focusedField: LineCheckField?
//
//    var body: some View {
//        VStack(alignment: .leading, spacing: 8) {
//            Text(input.item.itemName ?? "-")
//                .font(.headline)
//
//            if input.item.tempTaken {
//                TextField(
//                    "Temperature",
//                    text: $input.temperature
//                )
//                .keyboardType(.decimalPad)
//                .focused($focusedField, equals: .temperature(input.id))
//                .textFieldStyle(.roundedBorder)
//            }
//
//            TextEditor(text: $input.observations)
//                .focused($focusedField, equals: .observation(input.id))
//                .frame(minHeight: 60)
//                .overlay(
//                    RoundedRectangle(cornerRadius: 8)
//                        .stroke(focusedField == .observation(input.id) ? Color.blue : Color.secondary.opacity(0.5))
//                )
//        }
//        .padding()
//        .background(.ultraThinMaterial)
//        .clipShape(RoundedRectangle(cornerRadius: 12))
//    }
//}

// MARK: - Preview
struct LineCheckDetailView_Previews: PreviewProvider {
    static var previews: some View {
        LineCheckDetailView(lineCheckId: "1234", locationId: "5678")
    }
}

