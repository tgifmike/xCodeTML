//
//  LineCheckDetailVM.swift
//  tml.2.0
//
//  Created by mike on 5/6/26.
//

import Foundation
import SwiftUI
import Combine

@MainActor
final class LineCheckDetailVM: ObservableObject {

    // MARK: FLAT STATE (single source of truth)
    @Published var items: [LineCheckItemState] = []
    @Published var lineCheck: LineCheckDto?

    // MARK: Loading
    @Published var isLoading = false
    @Published var error: String?

    // MARK: Saving
    @Published var isSaving = false
    @Published var saveError: String?
    @Published var saveSuccess = false
   

    // MARK: Dirty check
    private var originalItems: [LineCheckItemState] = []

    // MARK: PROGRESS

    var totalItems: Int {
        items.count
    }

    var completedItems: Int {
        items.filter {
            $0.isMissing ||
            !$0.temperature.isEmpty ||
            $0.isChecked != nil
        }.count
    }

    var progress: Double {
        guard totalItems > 0 else { return 0 }
        return Double(completedItems) / Double(totalItems)
    }

    var progressColor: Color {
        if progress >= 1 { return .green }
        if progress > 0.7 { return .orange }
        return .red
    }

    var hasChanges: Bool {
        items != originalItems
    }

    // MARK: LOAD

    func load(lineCheckId: String) async {
        isLoading = true
        error = nil

        do {
            let response = try await LineCheckApi.shared.getLineCheckById(lineCheckId: lineCheckId)

            let flat: [LineCheckItemState] = response.stations.flatMap { station in
                station.items.map { item in
                    LineCheckItemState(
                        id: UUID(uuidString: item.id ?? "") ?? UUID(),
                        stationId: UUID(uuidString: station.id) ?? UUID(),
                        stationName: station.stationName ?? "Unnamed",
                        item: item,
                        temperature: item.temperature.map { "\($0)" } ?? "",
                        observations: item.observations ?? "",
                        isChecked: nil,
                        isMissing: item.isMissing ?? false
                    )
                }
            }

            self.items = flat
            self.originalItems = flat
            self.lineCheck = response

        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: SAVE

    func save(current: LineCheckDto?) async {
        guard var current else { return }

        isSaving = true
        saveError = nil

        do {
            let grouped = Dictionary(grouping: items, by: { $0.stationId })

            current.stations = grouped.map { (stationId, items) in
                LineCheckStationDto(
                    id: stationId.uuidString,
                    stationName: items.first?.stationName ?? "",
                    items: items.map { item in

                        var dto = item.item
                        dto.isMissing = item.isMissing

                        if item.isMissing {
                            dto.temperature = nil
                            dto.itemChecked = nil

                        } else if item.item.tempTaken {
                            dto.temperature = item.temperature.isEmpty ? nil : Float(item.temperature)
                            dto.itemChecked = nil

                        } else {
                            dto.itemChecked = item.isChecked
                            dto.temperature = nil
                        }

                        dto.observations = item.observations
                        return dto
                    }
                )
            }

            _ = try await LineCheckApi.shared.saveLineCheck(current)

            saveSuccess = true

        } catch {
            saveError = error.localizedDescription
        }

        isSaving = false
    }
}
