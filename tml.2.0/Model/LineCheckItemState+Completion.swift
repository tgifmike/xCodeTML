import Foundation

extension LineCheckItemState {
    var isCompleteForLineCheck: Bool {
        if isMissing {
            return !observations.isEmpty
        }

        if failedItemRequiresObservation {
            return false
        }

        if let criterionResponses = item.criterionResponses,
           !criterionResponses.isEmpty {
            if item.tempTaken && !hasTemperatureCriterion(criterionResponses) && temperature.isEmpty {
                return false
            }

            return criterionResponses
                .filter(isRequired)
                .allSatisfy(isRequiredCriterionAnswered)
        }

        if item.tempTaken {
            return !temperature.isEmpty && isChecked != nil
        }

        return isChecked != nil
    }

    var validationMessage: String? {
        let itemName = item.itemName ?? "This item"

        if failedItemRequiresObservation {
            let reasons = detailedFailureReasons

            if reasons.count == 1, let reason = reasons.first {
                return "\(itemName) has failed: \(reason) This failure requires an observation to be entered."
            }

            let bullets = reasons.map { "- \($0)" }.joined(separator: "\n")
            return "\(itemName) has failed:\n\(bullets)\nThese failures require an observation to be entered."
        }

        if !isCompleteForLineCheck {
            return "Please finish \(itemName) before saving."
        }

        return nil
    }

    private func isRequiredCriterionAnswered(_ response: LineCheckCriterionResponseDto) -> Bool {
        if isMissingCriterion(response) {
            return true
        }

        if isTemperatureCriterion(response) {
            guard !temperature.isEmpty else {
                return !requiresFailureNotes(response) || !observations.isEmpty
            }

            return !requiresFailureNotes(response)
            || !isFailedOrMissingRequiredTemperature(response)
            || !observations.isEmpty
        }

        if isBooleanCriterion(response) {
            guard let answer = response.booleanAnswer else { return false }
            return !requiresFailureNotes(response) || answer != false || !observations.isEmpty
        }

        if isNumberCriterion(response) {
            guard let answer = response.numberAnswer else { return false }
            return !requiresFailureNotes(response) || !isFailedNumber(answer, response: response) || !observations.isEmpty
        }

        if isTextCriterion(response) {
            return response.textAnswer?.isEmpty == false
        }

        if isNotesCriterion(response) {
            return response.notes?.isEmpty == false || !observations.isEmpty
        }

        if isPhotoCriterion(response) {
            return (response.photoCount ?? 0) > 0
        }

        return true
    }

    private func isRequired(_ response: LineCheckCriterionResponseDto) -> Bool {
        response.required == true
    }

    private func criterionKey(for response: LineCheckCriterionResponseDto) -> String {
        [response.criterionType, response.responseType, response.criterionName, response.label]
            .compactMap { $0 }
            .joined(separator: " ")
            .lowercased()
    }

    private func isMissingCriterion(_ response: LineCheckCriterionResponseDto) -> Bool {
        criterionKey(for: response).contains("missing")
    }

    private func isTemperatureCriterion(_ response: LineCheckCriterionResponseDto) -> Bool {
        let key = criterionKey(for: response)
        return key.contains("temperature") || key.contains("temp")
    }

    private func hasTemperatureCriterion(_ responses: [LineCheckCriterionResponseDto]) -> Bool {
        responses.contains { response in
            isTemperatureCriterion(response)
        }
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

    private func isNumberCriterion(_ response: LineCheckCriterionResponseDto) -> Bool {
        let key = criterionKey(for: response)
        return key.contains("number") || key.contains("numeric")
    }

    private func isTextCriterion(_ response: LineCheckCriterionResponseDto) -> Bool {
        criterionKey(for: response).contains("text")
    }

    private func isNotesCriterion(_ response: LineCheckCriterionResponseDto) -> Bool {
        criterionKey(for: response).contains("notes")
    }

    private func isPhotoCriterion(_ response: LineCheckCriterionResponseDto) -> Bool {
        criterionKey(for: response).contains("photo")
    }

    private func requiresFailureNotes(_ response: LineCheckCriterionResponseDto) -> Bool {
        response.requireNotesOnFailure ?? false
    }

    private var failedItemRequiresObservation: Bool {
        guard observations.isEmpty else { return false }

        if isMissing {
            return true
        }

        if isFailedTemperature {
            return true
        }

        if isChecked == false {
            return true
        }

        return item.criterionResponses?.contains { response in
            if isMissingCriterion(response) {
                return false
            }

            if isTemperatureCriterion(response) {
                return isFailedOrMissingRequiredTemperature(response)
            }

            if isBooleanCriterion(response), response.booleanAnswer == false {
                return true
            }

            if isNumberCriterion(response) {
                return isFailedOrMissingRequiredNumber(response)
            }

            return false
        } ?? false
    }

    private var detailedFailureReasons: [String] {
        var reasons: [String] = []

        if isMissing {
            reasons.append("Item is marked missing.")
        }

        if isFailedTemperature {
            reasons.append(temperatureFailureReason(value: Float(temperature), min: item.minTemp, max: item.maxTemp))
        }

        if isChecked == false {
            reasons.append("Item was marked fail.")
        }

        item.criterionResponses?.forEach { response in
            if isMissingCriterion(response) {
                return
            }

            let name = response.label ?? response.criterionName ?? "Criterion"

            if isTemperatureCriterion(response) {
                if temperature.isEmpty, response.required == true {
                    reasons.append("\(name) is required but was not entered.")
                } else if isFailedOrMissingRequiredTemperature(response) {
                    reasons.append(temperatureFailureReason(value: Float(temperature), min: response.minValue, max: response.maxValue))
                }
            } else if isBooleanCriterion(response), response.booleanAnswer == false {
                reasons.append("\(name) was marked fail.")
            } else if isNumberCriterion(response) {
                if response.numberAnswer == nil, response.required == true {
                    reasons.append("\(name) is required but was not entered.")
                } else if let answer = response.numberAnswer,
                          isFailedNumber(answer, response: response) {
                    reasons.append(numberFailureReason(name: name, value: answer, response: response))
                }
            } else if response.requiresCorrection == true {
                reasons.append("\(name) requires correction.")
            }
        }

        return reasons.isEmpty ? ["Correction is required."] : reasons
    }

    private func isFailedOrMissingRequiredTemperature(_ response: LineCheckCriterionResponseDto) -> Bool {
        guard !temperature.isEmpty else {
            return response.required == true
        }

        guard let value = Float(temperature) else {
            return response.required == true
        }

        return isFailedNumber(value, response: response)
    }

    private func isFailedOrMissingRequiredNumber(_ response: LineCheckCriterionResponseDto) -> Bool {
        guard let answer = response.numberAnswer else {
            return response.required == true
        }

        return isFailedNumber(answer, response: response)
    }

    private func numberFailureReason(
        name: String,
        value: Float,
        response: LineCheckCriterionResponseDto
    ) -> String {
        let unit = response.unit.map { " \($0)" } ?? ""
        return "\(name) was \(formattedNumber(value))\(unit); acceptable range is \(formattedRange(min: response.minValue, max: response.maxValue))\(unit)."
    }

    private func temperatureFailureReason(value: Float?, min: Float?, max: Float?) -> String {
        guard let value else {
            return "Temperature is outside the acceptable range."
        }

        return "Temperature was \(formattedNumber(value)); acceptable range is \(formattedRange(min: min, max: max))."
    }

    private func formattedRange(min: Float?, max: Float?) -> String {
        switch (min, max) {
        case let (min?, max?):
            return "\(formattedNumber(min))-\(formattedNumber(max))"
        case let (min?, nil):
            return "at least \(formattedNumber(min))"
        case let (nil, max?):
            return "no more than \(formattedNumber(max))"
        default:
            return "the configured range"
        }
    }

    private func formattedNumber(_ value: Float) -> String {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 1
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
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

    private var isFailedTemperature: Bool {
        guard let value = Float(temperature) else { return false }

        if let minTemp = item.minTemp, value < minTemp {
            return true
        }

        if let maxTemp = item.maxTemp, value > maxTemp {
            return true
        }

        return false
    }
}
