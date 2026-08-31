import Foundation

struct LineCheckCorrectionRules {

    static func correctionReasons(for item: LineCheckItemDto) -> [String] {
        var reasons: [String] = []

        if item.isMissing == true {
            reasons.append("Missing")
        }

        if isOutOfTemperatureRange(item) {
            reasons.append("Temp out of range")
        }

        reasons.append(contentsOf: failedCriterionReasons(for: item))

        if hasIncorrectPrep(item) {
            reasons.append("Prepared wrong")
        }

        return reasons
    }

    static func hasCorrectionIssue(_ item: LineCheckItemDto) -> Bool {
        !correctionReasons(for: item).isEmpty
    }

    static func isOutOfTemperatureRange(_ item: LineCheckItemDto) -> Bool {
        guard let temperature = item.temperature else { return false }

        if let minTemp = item.minTemp, temperature < minTemp {
            return true
        }

        if let maxTemp = item.maxTemp, temperature > maxTemp {
            return true
        }

        return false
    }

    static func hasIncorrectPrep(_ item: LineCheckItemDto) -> Bool {
        if item.criterionResponses?.isEmpty == false {
            return false
        }

        return item.itemChecked == false
    }

    static func failedCriterionReasons(for item: LineCheckItemDto) -> [String] {
        item.criterionResponses?.compactMap { response in
            if isMissingCriterion(response) {
                return nil
            }

            let failed = response.requiresCorrection == true
            || response.booleanAnswer == false
            || isFailedNumber(response)

            guard failed else { return nil }
            return response.label ?? response.criterionName ?? "Criterion failed"
        } ?? []
    }

    static func isFailedNumber(_ response: LineCheckCriterionResponseDto) -> Bool {
        guard let numberAnswer = response.numberAnswer else { return false }

        if let minValue = response.minValue, numberAnswer < minValue {
            return true
        }

        if let maxValue = response.maxValue, numberAnswer > maxValue {
            return true
        }

        return false
    }

    static func isMissingCriterion(_ response: LineCheckCriterionResponseDto) -> Bool {
        [response.criterionType, response.responseType, response.criterionName, response.label]
            .compactMap { $0 }
            .joined(separator: " ")
            .lowercased()
            .contains("missing")
    }
}
