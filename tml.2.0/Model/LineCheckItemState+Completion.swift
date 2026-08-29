import Foundation

extension LineCheckItemState {
    var isCompleteForLineCheck: Bool {
        if isMissing {
            return !observations.isEmpty
        }

        if item.tempTaken && temperature.isEmpty {
            return false
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

        if item.tempTaken && temperature.isEmpty {
            return "\(itemName) needs a temperature before saving."
        }

        if failedItemRequiresObservation {
            return "\(itemName) has failed due to temperature not in bounds, item not prepared correctly, or item missing. Please leave an observation."
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
            guard !temperature.isEmpty else { return false }
            return !requiresFailureNotes(response) || !isFailedTemperature || !observations.isEmpty
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

            if isBooleanCriterion(response), response.booleanAnswer == false {
                return true
            }

            if isNumberCriterion(response),
               let answer = response.numberAnswer,
               isFailedNumber(answer, response: response) {
                return true
            }

            return false
        } ?? false
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
