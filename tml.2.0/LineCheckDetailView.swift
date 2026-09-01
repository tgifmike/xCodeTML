import SwiftUI

struct LineCheckDetailView: View {

    let lineCheckId: String
    let locationId: String
    let locationName: String
    let accountName: String
    let isReadOnly: Bool
    let onComplete: (() -> Void)?

    init(
        lineCheckId: String,
        locationId: String,
        locationName: String,
        accountName: String,
        isReadOnly: Bool = false,
        onComplete: (() -> Void)? = nil
    ) {
        self.lineCheckId = lineCheckId
        self.locationId = locationId
        self.locationName = locationName
        self.accountName = accountName
        self.isReadOnly = isReadOnly
        self.onComplete = onComplete
    }

    @StateObject private var vm = LineCheckDetailVM()

//    @State private var lineCheck: LineCheckDto?

    @EnvironmentObject var appSettings: AppSettings
    @Environment(\.dismiss) private var dismiss

    @FocusState private var focusedField: LineCheckField?

    var body: some View {

        NavigationStack {

            content
                .navigationTitle("Line Check")
                .navigationBarTitleDisplayMode(.inline)
        }
        .task {
            await vm.load(lineCheckId: lineCheckId)
        }
        .overlay {

            if let error = vm.saveError ?? vm.error {

                CustomAlertView(
                    title: "Error",
                    message: error,
                    buttonTitle: "OK"
                ) {
                    vm.error = nil
                    vm.saveError = nil
                }
            }
        }
        .alert("Success", isPresented: $vm.saveSuccess) {

            Button("OK") { }

        } message: {

            Text(vm.saveSuccessMessage)
        }
    }

    // MARK: CONTENT

    @ViewBuilder
    private var content: some View {

        if vm.isLoading {

            ProgressView("Loading…")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = vm.error {

            Text(error)
                .foregroundColor(.red)

        } else {

            mainView
        }
    }

    // MARK: MAIN VIEW

//    private var mainView: some View {
//
//        let stationNames = Array(
//            Set(vm.items.map(\.stationName))
//        ).sorted()
//
//        return VStack(spacing: 0) {
//
//            // STICKY HEADER
//            progressHeader
//                .padding(.horizontal)
//                .padding(.top, 4)
//                .background(.ultraThinMaterial)
//                .zIndex(1)
//            
//            ScrollView {
//
//                LazyVStack(spacing: 12) {
//
//                    headerSection
//
//                    ForEach(stationNames, id: \.self) { stationName in
//
//                        LineCheckStationSection(
//                            stationName: stationName,
//                            items: bindingForStation(stationName),
//                            focusedField: $focusedField
//                        )
//                    }
//
//                    saveButton
//                        .padding(.top, 8)
//                }
//                .padding()
//                .padding(.top, 4)
//            }
//            .scrollDismissesKeyboard(.interactively)
//        }
//        .toolbar {
//
//            ToolbarItemGroup(placement: .keyboard) {
//
//                Spacer()
//
//                Button("Done") {
//                    focusedField = nil
//                }
//            }
//        }
//    }
    
    @ViewBuilder
    private var mainView: some View {
        if isReadOnly {
            historyView
        } else {
            editableLineCheckView
        }
    }

    private var editableLineCheckView: some View {
        let stationNames = Array(
            Set(vm.items.map(\.stationName))
        ).sorted()

        return ScrollViewReader { scrollProxy in
            VStack(spacing: 0) {
                progressHeader
                    .padding(.horizontal)
                    .padding(.top, 4)
                    .background(.ultraThinMaterial)
                    .zIndex(1)

                ScrollView {
                    LazyVStack(spacing: 12) {
                        headerSection

                        ForEach(stationNames, id: \.self) { stationName in
                            LineCheckStationSection(
                                stationName: stationName,
                                lineCheckId: vm.lineCheck?.id ?? lineCheckId,
                                locationId: locationId,
                                items: bindingForStation(stationName),
                                focusedField: $focusedField,
                                isReadOnly: false
                            )
                        }

                        Spacer()
                            .frame(height: 100)
                    }
                    .padding()
                    .padding(.top, 4)
                }
                .scrollDismissesKeyboard(.interactively)

                VStack {
                    saveButton(scrollProxy: scrollProxy)
                }
                .padding()
                .background(.ultraThinMaterial)
            }
        }
    }

    private var historyView: some View {
        let stationNames = Array(
            Set(vm.items.map(\.stationName))
        ).sorted()

        return ScrollView {
            LazyVStack(spacing: 12) {
                headerSection
                readOnlyBanner

                ForEach(stationNames, id: \.self) { stationName in
                    LineCheckHistoryStationSection(
                        stationName: stationName,
                        items: vm.items.filter { $0.stationName == stationName }
                    )
                }
            }
            .padding()
            .padding(.top, 4)
        }
    }

    // MARK: BINDING

    private func bindingForStation(
        _ stationName: String
    ) -> Binding<[LineCheckItemState]> {

        Binding {

            vm.items.filter {
                $0.stationName == stationName
            }

        } set: { updatedItems in

            for updated in updatedItems {

                if let index = vm.items.firstIndex(where: {
                    $0.id == updated.id
                }) {

                    vm.items[index] = updated
                }
            }
        }
    }

    // MARK: PROGRESS

    private var progressHeader: some View {

        VStack(alignment: .leading, spacing: 8) {

            HStack {

                Text("Total Line Check Progress")
                    .font(.headline)

                Spacer()

                Text("\(vm.completedItems)/\(vm.totalItems)")
                    .foregroundColor(.blue)
                    .font(.caption)
                
                Text(vm.progress.formatted(.percent.precision(.fractionLength(0))))
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(vm.progressColor.opacity(0.10))
                    .foregroundColor(vm.progressColor)
                    .clipShape(Capsule())
            }

            ProgressView(value: vm.progress)
                .progressViewStyle(.linear)
                .tint(vm.progressColor)
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.1), radius: 3, y: 2)
    }

    
    // MARK: HEADER

    private var headerSection: some View {

        VStack(spacing: 14) {

            HStack(alignment: .top) {

                // ACCOUNT
                VStack(alignment: .leading, spacing: 6) {

                    Label("Account", systemImage: "building.2.fill")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text(accountName)
                        .font(.headline)
                        .foregroundColor(.blue)
                }

                Spacer()

                // LOCATION
                VStack(alignment: .trailing, spacing: 6) {

                    Label("Location", systemImage: "mappin.and.ellipse")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text(locationName)
                        .font(.headline)
                        .foregroundColor(.blue)
                }
            }

            Divider()

            HStack(alignment: .top) {

                // USERNAME
                VStack(alignment: .leading, spacing: 6) {

                    Label("Conducted By", systemImage: "person.fill")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text(vm.lineCheck?.username ?? "-")
                        .font(.headline)
                        .foregroundColor(.blue)
                }

                Spacer()

                // START TIME
                VStack(alignment: .trailing, spacing: 6) {

                    Label("Started", systemImage: "clock.fill")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text(startTimeText)
                        .font(.headline)
                        .foregroundColor(.blue)
                }
            }
        }
        .padding()
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var readOnlyBanner: some View {
        Label("Read-only history view", systemImage: "lock.fill")
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: START TIME FORMAT

    private var startTimeText: String {

        guard let checkTime = vm.lineCheck?.checkTime else {
            return "-"
        }

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short

        return formatter.string(from: checkTime)
    }
    
    // MARK: SAVE

    private func saveButton(scrollProxy: ScrollViewProxy) -> some View {

        Button {

            guard vm.validateBeforeSave() else {
                if let itemId = vm.firstIncompleteItem?.id {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        scrollProxy.scrollTo(itemId, anchor: .center)
                    }
                }
                return
            }

            Task {
                await vm.save(
                    current: vm.lineCheck,
                    locationId: locationId,
                    locationName: locationName,
                    accountName: accountName
                )
                
                if vm.saveSuccess {
                    if let onComplete {
                        onComplete()
                    } else {
                        dismiss()
                    }
                }
            }

        } label: {

            if vm.isSaving {

                ProgressView()
                    .frame(maxWidth: .infinity)

            } else {

                Text("Save Line Check")
                    .frame(maxWidth: .infinity)
                    .fontWeight(.bold)
                    .font(.headline)
            }
        }
        .buttonStyle(.borderedProminent)
        .disabled(vm.isSaving || !vm.hasChanges)
    }
}

private struct LineCheckHistoryStationSection: View {

    let stationName: String
    let items: [LineCheckItemState]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Label(stationName, systemImage: "square.grid.2x2")
                    .font(.headline)

                Spacer()

                Text("\(items.count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.primary.opacity(0.06))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 2)

            ForEach(items) { item in
                LineCheckHistoryItemCard(item: item)
            }
        }
    }
}

private struct LineCheckHistoryItemCard: View {

    let item: LineCheckItemState

    private var dto: LineCheckItemDto {
        item.item
    }

    private var correctionReasons: [String] {
        LineCheckCorrectionRules.correctionReasons(for: dto)
    }

    private var hasFailure: Bool {
        !correctionReasons.isEmpty
    }

    private var hasCorrectionDetails: Bool {
        dto.isCorrected == true ||
        dto.correctiveNotes?.isEmpty == false ||
        dto.correctedByName?.isEmpty == false ||
        dto.correctedAt != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(dto.itemName ?? "Unnamed Item")
                        .font(.headline)

                    Text(statusText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(statusColor)
                }

                Spacer()

                Image(systemName: statusIcon)
                    .foregroundStyle(statusColor)
                    .font(.title3)
            }

            if hasFailure {
                FlowBadgeGroup(items: correctionReasons, color: .orange)
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Original Answers")
                    .font(.subheadline.weight(.semibold))

                ForEach(originalAnswerRows, id: \.title) { row in
                    HistoryAnswerRow(title: row.title, value: row.value)
                }
            }

            if let observations = dto.observations,
               !observations.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                HistoryNoteBlock(title: "Observation", text: observations)
            }

            if hasCorrectionDetails {
                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Correction")
                        .font(.subheadline.weight(.semibold))

                    if dto.isCorrected == true {
                        Label("Marked corrected", systemImage: "checkmark.circle.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.green)
                    }

                    if let correctedBy = dto.correctedByName, !correctedBy.isEmpty {
                        HistoryAnswerRow(title: "Corrected By", value: correctedBy)
                    }

                    if let correctedAt = dto.correctedAt {
                        HistoryAnswerRow(title: "Corrected At", value: formattedDate(correctedAt))
                    }

                    if let notes = dto.correctiveNotes,
                       !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        HistoryNoteBlock(title: "Correction Notes", text: notes)
                    }
                }
            }
        }
        .padding(14)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        }
    }

    private var statusText: String {
        if dto.isCorrected == true {
            return "Corrected"
        }

        return hasFailure ? "Needs Correction" : "Passed"
    }

    private var statusIcon: String {
        if dto.isCorrected == true {
            return "checkmark.circle.fill"
        }

        return hasFailure ? "exclamationmark.triangle.fill" : "checkmark.circle"
    }

    private var statusColor: Color {
        if dto.isCorrected == true {
            return .green
        }

        return hasFailure ? .orange : .green
    }

    private var originalAnswerRows: [(title: String, value: String)] {
        var rows: [(String, String)] = []

        if dto.isMissing == true {
            rows.append(("Missing", "Yes"))
        }

        if let temperature = dto.temperature {
            rows.append(("Temperature", "\(formattedNumber(temperature)) F"))
        }

        if dto.criterionResponses?.isEmpty == false {
            dto.criterionResponses?.forEach { response in
                rows.append((criterionLabel(for: response), answerText(for: response)))
            }
        } else if dto.checkMark {
            rows.append(("Prepared Correctly", dto.itemChecked == true ? "Pass" : "Fail"))
        }

        return rows.isEmpty ? [("Result", dto.itemChecked == false ? "Fail" : "Pass")] : rows
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

        if let textAnswer = response.textAnswer, !textAnswer.isEmpty {
            return textAnswer
        }

        if let notes = response.notes, !notes.isEmpty {
            return notes
        }

        return response.required == true ? "Not answered" : "-"
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func formattedNumber(_ value: Float) -> String {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 1
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}

private struct HistoryAnswerRow: View {

    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 130, alignment: .leading)

            Text(value)
                .font(.caption.weight(.medium))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct HistoryNoteBlock: View {

    let title: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(text)
                .font(.callout)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }
}

private struct FlowBadgeGroup: View {

    let items: [String]
    let color: Color

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                badges
            }

            VStack(alignment: .leading, spacing: 8) {
                badges
            }
        }
    }

    private var badges: some View {
        ForEach(items, id: \.self) { item in
            Text(item)
                .font(.caption.weight(.semibold))
                .foregroundStyle(color)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(color.opacity(0.12))
                .clipShape(Capsule())
        }
    }
}
