import Foundation
import UIKit

@MainActor
enum LineCheckPrinter {
    enum PrintError: LocalizedError {
        case printingUnavailable
        case unsupportedPDF

        var errorDescription: String? {
            switch self {
            case .printingUnavailable:
                return "Printing is not available on this device."
            case .unsupportedPDF:
                return "This line check PDF could not be prepared for printing."
            }
        }
    }

    static func print(lineCheck: LineCheckDto, accountName: String, locationName: String) throws {
        guard UIPrintInteractionController.isPrintingAvailable else {
            throw PrintError.printingUnavailable
        }

        let pdfData = LineCheckPDFRenderer(
            lineCheck: lineCheck,
            accountName: accountName,
            locationName: locationName
        ).render()

        guard UIPrintInteractionController.canPrint(pdfData) else {
            throw PrintError.unsupportedPDF
        }

        let printInfo = UIPrintInfo(dictionary: nil)
        printInfo.outputType = .general
        printInfo.jobName = "Line Check - \(locationName)"

        let controller = UIPrintInteractionController.shared
        controller.printInfo = printInfo
        controller.printingItem = pdfData
        controller.present(animated: true, completionHandler: nil)
    }
}

private struct LineCheckPDFRenderer {
    private let lineCheck: LineCheckDto
    private let accountName: String
    private let locationName: String
    private let pageBounds = CGRect(x: 0, y: 0, width: 612, height: 792)
    private let margin: CGFloat = 42

    init(lineCheck: LineCheckDto, accountName: String, locationName: String) {
        self.lineCheck = lineCheck
        self.accountName = accountName
        self.locationName = locationName
    }

    func render() -> Data {
        let renderer = UIGraphicsPDFRenderer(bounds: pageBounds)

        return renderer.pdfData { context in
            var cursor = PDFCursor(context: context, pageBounds: pageBounds, margin: margin)
            cursor.beginPage()
            drawHeader(using: &cursor)
            drawSummary(using: &cursor)
            drawStations(using: &cursor)
            drawFooter(using: &cursor)
        }
    }

    private func drawHeader(using cursor: inout PDFCursor) {
        cursor.drawText(
            "Line Check Report",
            font: .systemFont(ofSize: 24, weight: .bold),
            color: .label,
            spacingAfter: 8
        )

        cursor.drawText(
            "\(accountName) - \(locationName)",
            font: .systemFont(ofSize: 14, weight: .semibold),
            color: .secondaryLabel,
            spacingAfter: 18
        )
    }

    private func drawSummary(using cursor: inout PDFCursor) {
        cursor.drawSectionTitle("Summary")
        cursor.drawKeyValue("Conducted By", lineCheck.username ?? "-")
        cursor.drawKeyValue("Started", formattedDate(lineCheck.checkTime))
        cursor.drawKeyValue("Completed", formattedDate(lineCheck.completedAt))
        cursor.drawKeyValue("Duration", formattedDuration(lineCheck.durationSeconds))
        cursor.drawKeyValue("Stations", "\(lineCheck.stations.count)")
        cursor.drawKeyValue("Items", "\(allItems.count)")
        cursor.drawKeyValue("Needs Correction", "\(issueCount)")
        cursor.addSpacing(14)
    }

    private func drawStations(using cursor: inout PDFCursor) {
        for station in sortedStations {
            cursor.drawSectionTitle(station.stationName ?? "Unnamed Station")

            let items = station.items.sorted {
                ($0.sortOrder ?? 0, $0.itemName ?? "") < ($1.sortOrder ?? 0, $1.itemName ?? "")
            }

            if items.isEmpty {
                cursor.drawText(
                    "No items recorded.",
                    font: .systemFont(ofSize: 10),
                    color: .secondaryLabel,
                    spacingAfter: 8
                )
            } else {
                for item in items {
                    drawItem(item, using: &cursor)
                }
            }

            cursor.addSpacing(6)
        }
    }

    private func drawItem(_ item: LineCheckItemDto, using cursor: inout PDFCursor) {
        let reasons = LineCheckCorrectionRules.correctionReasons(for: item)
        let status: String

        if item.isCorrected == true {
            status = "Corrected"
        } else if reasons.isEmpty {
            status = "Passed"
        } else {
            status = "Needs Correction"
        }

        cursor.drawText(
            "\(item.itemName ?? "Unnamed Item") - \(status)",
            font: .systemFont(ofSize: 12, weight: .semibold),
            color: reasons.isEmpty || item.isCorrected == true ? .label : .systemOrange,
            spacingAfter: 5
        )

        if !reasons.isEmpty {
            cursor.drawKeyValue("Issues", reasons.joined(separator: ", "))
        }

        for row in originalAnswerRows(for: item) {
            cursor.drawKeyValue(row.title, row.value)
        }

        if let observations = trimmed(item.observations) {
            cursor.drawKeyValue("Observation", observations)
        }

        if item.isCorrected == true || trimmed(item.correctiveNotes) != nil || trimmed(item.correctedByName) != nil || item.correctedAt != nil {
            cursor.drawKeyValue("Correction", item.isCorrected == true ? "Marked corrected" : "Recorded")

            if let correctedByName = trimmed(item.correctedByName) {
                cursor.drawKeyValue("Corrected By", correctedByName)
            }

            if let correctedAt = item.correctedAt {
                cursor.drawKeyValue("Corrected At", formattedDate(correctedAt))
            }

            if let correctiveNotes = trimmed(item.correctiveNotes) {
                cursor.drawKeyValue("Correction Notes", correctiveNotes)
            }
        }

        cursor.addSpacing(8)
        cursor.drawRule()
        cursor.addSpacing(8)
    }

    private func drawFooter(using cursor: inout PDFCursor) {
        cursor.addSpacing(10)
        cursor.drawText(
            "Generated on \(formattedDate(Date()))",
            font: .systemFont(ofSize: 9),
            color: .tertiaryLabel,
            spacingAfter: 0
        )
    }

    private var sortedStations: [LineCheckStationDto] {
        lineCheck.stations.sorted { ($0.stationName ?? "") < ($1.stationName ?? "") }
    }

    private var allItems: [LineCheckItemDto] {
        lineCheck.stations.flatMap(\.items)
    }

    private var issueCount: Int {
        allItems.filter { LineCheckCorrectionRules.hasCorrectionIssue($0) }.count
    }

    private func originalAnswerRows(for item: LineCheckItemDto) -> [(title: String, value: String)] {
        var rows: [(String, String)] = []

        if item.isMissing == true {
            rows.append(("Missing", "Yes"))
        }

        if let temperature = item.temperature {
            rows.append(("Temperature", "\(formattedNumber(temperature)) F"))
        }

        if item.criterionResponses?.isEmpty == false {
            item.criterionResponses?.forEach { response in
                rows.append((criterionLabel(for: response), answerText(for: response)))
            }
        } else if item.checkMark {
            rows.append(("Prepared Correctly", item.itemChecked == true ? "Pass" : "Fail"))
        }

        return rows.isEmpty ? [("Result", item.itemChecked == false ? "Fail" : "Pass")] : rows
    }

    private func criterionLabel(for response: LineCheckCriterionResponseDto) -> String {
        response.label ?? response.criterionName ?? "Criterion"
    }

    private func answerText(for response: LineCheckCriterionResponseDto) -> String {
        if let booleanAnswer = response.booleanAnswer {
            return booleanAnswer ? "Pass" : "Fail"
        }

        if let numberAnswer = response.numberAnswer {
            let unit = response.unit.map { " \($0)" } ?? ""
            return "\(formattedNumber(numberAnswer))\(unit)"
        }

        if let textAnswer = trimmed(response.textAnswer) {
            return textAnswer
        }

        if let notes = trimmed(response.notes) {
            return notes
        }

        return response.required == true ? "Not answered" : "-"
    }

    private func formattedDate(_ date: Date?) -> String {
        guard let date else { return "-" }

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func formattedDuration(_ seconds: Int?) -> String {
        guard let seconds else { return "-" }

        let minutes = seconds / 60
        let remainingSeconds = seconds % 60

        if minutes == 0 {
            return "\(remainingSeconds) sec"
        }

        return "\(minutes) min \(remainingSeconds) sec"
    }

    private func formattedNumber(_ value: Float) -> String {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 1
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private func trimmed(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }

        return trimmed
    }
}

private struct PDFCursor {
    let context: UIGraphicsPDFRendererContext
    let pageBounds: CGRect
    let margin: CGFloat

    private(set) var y: CGFloat = 0

    var contentWidth: CGFloat {
        pageBounds.width - (margin * 2)
    }

    mutating func beginPage() {
        context.beginPage()
        y = margin
    }

    mutating func addSpacing(_ spacing: CGFloat) {
        y += spacing
    }

    mutating func drawSectionTitle(_ text: String) {
        ensureSpace(36)
        drawText(
            text,
            font: .systemFont(ofSize: 15, weight: .bold),
            color: .label,
            spacingAfter: 7
        )
        drawRule()
        addSpacing(7)
    }

    mutating func drawKeyValue(_ key: String, _ value: String) {
        let keyWidth: CGFloat = 120
        let gap: CGFloat = 10
        let valueWidth = contentWidth - keyWidth - gap
        let attributes = textAttributes(font: .systemFont(ofSize: 10), color: .secondaryLabel)
        let valueAttributes = textAttributes(font: .systemFont(ofSize: 10, weight: .medium), color: .label)
        let keyHeight = textHeight(key, width: keyWidth, attributes: attributes)
        let valueHeight = textHeight(value, width: valueWidth, attributes: valueAttributes)
        let rowHeight = max(keyHeight, valueHeight)

        ensureSpace(rowHeight + 4)

        key.draw(
            in: CGRect(x: margin, y: y, width: keyWidth, height: keyHeight),
            withAttributes: attributes
        )
        value.draw(
            in: CGRect(x: margin + keyWidth + gap, y: y, width: valueWidth, height: valueHeight),
            withAttributes: valueAttributes
        )

        y += rowHeight + 4
    }

    mutating func drawText(
        _ text: String,
        font: UIFont,
        color: UIColor,
        spacingAfter: CGFloat
    ) {
        let attributes = textAttributes(font: font, color: color)
        let height = textHeight(text, width: contentWidth, attributes: attributes)
        ensureSpace(height + spacingAfter)

        text.draw(
            in: CGRect(x: margin, y: y, width: contentWidth, height: height),
            withAttributes: attributes
        )

        y += height + spacingAfter
    }

    mutating func drawRule() {
        ensureSpace(4)
        let path = UIBezierPath()
        path.move(to: CGPoint(x: margin, y: y))
        path.addLine(to: CGPoint(x: pageBounds.width - margin, y: y))
        UIColor.separator.setStroke()
        path.lineWidth = 0.5
        path.stroke()
        y += 4
    }

    private mutating func ensureSpace(_ neededHeight: CGFloat) {
        let maxY = pageBounds.height - margin
        if y + neededHeight > maxY {
            beginPage()
        }
    }

    private func textAttributes(font: UIFont, color: UIColor) -> [NSAttributedString.Key: Any] {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byWordWrapping
        paragraphStyle.lineSpacing = 2

        return [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraphStyle
        ]
    }

    private func textHeight(
        _ text: String,
        width: CGFloat,
        attributes: [NSAttributedString.Key: Any]
    ) -> CGFloat {
        let rect = NSString(string: text).boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes,
            context: nil
        )

        return ceil(rect.height)
    }
}
