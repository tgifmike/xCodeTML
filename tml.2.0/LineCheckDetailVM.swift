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
        items.filter(\.isCompleteForLineCheck).count
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

    var firstIncompleteItem: LineCheckItemState? {
        items.first { !$0.isCompleteForLineCheck }
    }

    func validateBeforeSave() -> Bool {
        guard let firstIncompleteItem else {
            saveError = nil
            return true
        }

        saveError = firstIncompleteItem.validationMessage
        ?? "Please finish \(firstIncompleteItem.item.itemName ?? "this item") in \(firstIncompleteItem.stationName) before saving."
        return false
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

    private func updatedCriterionResponses(
        _ responses: [LineCheckCriterionResponseDto]?,
        from item: LineCheckItemState
    ) -> [LineCheckCriterionResponseDto]? {
        guard let responses else { return nil }

        return responses.map { response in
            var updated = response
            let key = criterionKey(for: response)

            if key.contains("missing") {
                updated.booleanAnswer = item.isMissing
                if item.isMissing, !item.observations.isEmpty {
                    updated.notes = item.observations
                }
                return updated
            }

            if isPreparedCorrectlyCriterion(response) {
                let answer = item.isMissing ? false : (item.isChecked ?? response.booleanAnswer ?? true)
                updated.booleanAnswer = answer

                if answer == false, !item.observations.isEmpty {
                    updated.notes = item.observations
                }
                return updated
            }

            if item.isMissing {
                return updated
            }

            if isTemperatureCriterion(response) {
                updated.numberAnswer = Float(item.temperature)
                if isFailedTemperature(item), !item.observations.isEmpty {
                    updated.notes = item.observations
                }
            } else if isBooleanCriterion(response),
                      response.booleanAnswer == false,
                      !item.observations.isEmpty {
                updated.notes = item.observations
            } else if isNumberCriterion(response),
                      let answer = response.numberAnswer,
                      isFailedNumber(answer, response: response),
                      !item.observations.isEmpty {
                updated.notes = item.observations
            }

            return updated
        }
    }

    private func criterionKey(for response: LineCheckCriterionResponseDto) -> String {
        [response.criterionType, response.responseType, response.criterionName, response.label]
            .compactMap { $0 }
            .joined(separator: " ")
            .lowercased()
    }

    private func isTemperatureCriterion(_ response: LineCheckCriterionResponseDto) -> Bool {
        let key = criterionKey(for: response)
        return key.contains("temperature") || key.contains("temp")
    }

    private func isPreparedCorrectlyCriterion(_ response: LineCheckCriterionResponseDto) -> Bool {
        let key = criterionKey(for: response)
        return key.contains("prepared") || key.contains("prep") || key.contains("correct")
    }

    private func isBooleanCriterion(_ response: LineCheckCriterionResponseDto) -> Bool {
        let key = criterionKey(for: response)
        let responseType = response.responseType?
            .lowercased()
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: "-", with: "")
            ?? ""

        return responseType == "boolean"
        || responseType == "bool"
        || responseType == "checkbox"
        || responseType == "passfail"
        || key.contains("pass/fail")
        || key.contains("pass fail")
        || key.contains("standard")
        || key.contains("clean")
        || key.contains("stocked")
    }

    private func isNotesCriterion(_ response: LineCheckCriterionResponseDto) -> Bool {
        criterionKey(for: response).contains("notes")
    }

    private func isNumberCriterion(_ response: LineCheckCriterionResponseDto) -> Bool {
        let key = criterionKey(for: response)
        return key.contains("number") || key.contains("numeric")
    }

    private func isTextCriterion(_ response: LineCheckCriterionResponseDto) -> Bool {
        criterionKey(for: response).contains("text")
    }

    private func requiresFailureNotes(_ response: LineCheckCriterionResponseDto) -> Bool {
        response.requireNotesOnFailure ?? false
    }

    private func isFailedTemperature(_ item: LineCheckItemState) -> Bool {
        guard let value = Float(item.temperature) else { return false }

        if let minTemp = item.item.minTemp, value < minTemp {
            return true
        }

        if let maxTemp = item.item.maxTemp, value > maxTemp {
            return true
        }

        return false
    }

    private func isFailedNumber(_ value: Float, response: LineCheckCriterionResponseDto) -> Bool {
        if let minValue = response.minValue, value < minValue {
            return true
        }

        if let maxValue = response.maxValue, value > maxValue {
            return true
        }

        return false
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
                        dto.criterionResponses = updatedCriterionResponses(
                            dto.criterionResponses,
                            from: item
                        )

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
