////
////  LineCheckItemRowVM.swift
////  tml.2.0
////
////  Created by mike on 5/6/26.
////

import Foundation
import Combine
import SwiftUI

@MainActor
final class LineCheckItemRowVM: ObservableObject, Identifiable {

    // MARK: Identity

    let id: UUID
    let item: LineCheckItemDto

    // MARK: UI State

    @Published var temperature: String
    @Published var observations: String
    @Published var isChecked: Bool?
    @Published var isMissing: Bool

    // MARK: Init

    init(input: LineCheckItemInput) {
        self.id = input.id
        self.item = input.item
        self.temperature = input.temperature
        self.observations = input.observations
        self.isChecked = input.isChecked
        self.isMissing = input.isMissing
    }

    // MARK: Derived UI Rules

    var requiresTemperature: Bool {
        item.tempTaken
    }

    var requiresCheckmark: Bool {
        item.checkMark
    }

    var isComplete: Bool {

        if isMissing {
            return true
        }

        if requiresTemperature {
            return !temperature.isEmpty
        }

        if requiresCheckmark {
            return isChecked != nil
        }

        return true
    }

    // MARK: Validation Helpers

    var temperatureValue: Float? {
        Float(temperature)
    }

    var isTemperatureValid: Bool? {
        guard requiresTemperature,
              let value = temperatureValue,
              let min = item.minTemp,
              let max = item.maxTemp else {
            return nil
        }

        return value >= min && value <= max
    }

    var temperatureRangeText: String? {
        guard let min = item.minTemp,
              let max = item.maxTemp else { return nil }

        return "\(Int(min))°F – \(Int(max))°F"
    }

    // MARK: Reset Logic

    func setMissing(_ value: Bool) {
        isMissing = value

        if value {
            temperature = ""
            isChecked = nil
            observations = ""
        }
    }

    // MARK: Conversion Back to Input

    func toInput() -> LineCheckItemInput {
        LineCheckItemInput(
            id: id,
            item: item,
            temperature: temperature,
            observations: observations,
            isChecked: isChecked,
            isMissing: isMissing
        )
    }
}
