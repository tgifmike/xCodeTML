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
        items.filter(isItemComplete).count
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

    private func isItemComplete(_ item: LineCheckItemState) -> Bool {
        if item.isMissing {
            return true
        }

        if item.item.tempTaken {
            return !item.temperature.isEmpty && item.isChecked != nil
        }

        return item.isChecked != nil
    }

    private func normalizedPrepState(
        _ value: Bool?,
        isOpenLineCheck: Bool,
        temperature: String,
        observations: String,
        isMissing: Bool
    ) -> Bool? {
        let hasUserEntry = !temperature.isEmpty || !observations.isEmpty || isMissing

        if isOpenLineCheck && value == false && !hasUserEntry {
            return nil
        }

        return value
    }

    // MARK: LOAD

    func load(lineCheckId: String) async {
        isLoading = true
        error = nil

        do {
            let response = try await LineCheckApi.shared.getLineCheckById(lineCheckId: lineCheckId)

            let isOpenLineCheck = response.completedAt == nil

            let flat: [LineCheckItemState] = response.stations.flatMap { station in
                station.items.map { item in
                    let temperature = item.temperature.map { "\($0)" } ?? ""
                    let observations = item.observations ?? ""
                    let isMissing = item.isMissing ?? false
                    let isChecked = normalizedPrepState(
                        item.itemChecked,
                        isOpenLineCheck: isOpenLineCheck,
                        temperature: temperature,
                        observations: observations,
                        isMissing: isMissing
                    )

                    return LineCheckItemState(
                        id: UUID(uuidString: item.id ?? "") ?? UUID(),
                        stationId: UUID(uuidString: station.id) ?? UUID(),
                        stationName: station.stationName ?? "Unnamed",
                        item: item,
                        temperature: temperature,
                        observations: observations,
                        isChecked: isChecked,
                        isMissing: isMissing
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

                        } else {
                            dto.temperature = item.item.tempTaken && !item.temperature.isEmpty
                            ? Float(item.temperature)
                            : nil
                            dto.itemChecked = item.isChecked
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
