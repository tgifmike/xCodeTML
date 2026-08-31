import SwiftUI
import PhotosUI
import UIKit

struct LineCheckItemRow: View {

    @Binding var item: LineCheckItemState
    @FocusState.Binding var focusedField: LineCheckField?

    let isReadOnly: Bool
    let onFinalizeAction: () -> Void

    @Environment(\.horizontalSizeClass)
    private var horizontalSizeClass

    @State private var photos: [LineCheckPhotoDto] = []
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isShowingCamera = false
    @State private var isLoadingPhotos = false
    @State private var isUploadingPhoto = false
    @State private var isPhotosExpanded = false
    @State private var activeCriterionPhotoResponseId: String?
    @State private var photoError: String?

    // MARK: Validation

    private enum TempValidation {
        case empty
        case valid
        case invalid
    }

    private var validation: TempValidation {

        guard !item.temperature.isEmpty,
              let value = Float(item.temperature),
              let min = item.item.minTemp,
              let max = item.item.maxTemp else {
            return .empty
        }

        return (value >= min && value <= max)
        ? .valid
        : .invalid
    }

    private var hasInvalidTemperature: Bool {
        validation == .invalid
    }

    private var isPreparedIncorrectly: Bool {
        item.isChecked == false
    }

    private var rowSpacing: CGFloat {
        horizontalSizeClass == .compact ? 12 : 16
    }

    private var sectionSpacing: CGFloat {
        horizontalSizeClass == .compact ? 12 : 18
    }

    private var rowPadding: CGFloat {
        horizontalSizeClass == .compact ? 14 : 18
    }

    private var cardPadding: CGFloat {
        horizontalSizeClass == .compact ? 14 : 18
    }

    private var detailColumns: [GridItem] {
        if horizontalSizeClass == .compact {
            return [GridItem(.flexible(), alignment: .leading)]
        }

        return [
            GridItem(.flexible(), alignment: .leading),
            GridItem(.flexible(), alignment: .leading)
        ]
    }

    // MARK: Body

    var body: some View {

        VStack(alignment: .leading, spacing: rowSpacing) {

            headerSection

            adaptiveTopSection

            if hasNotes {
                notesSection
            }

            photoArea

            observationsSection

            if shouldShowCorrectionHistory {
                correctionHistorySection
            }
        }
        .task(id: item.id) {
            await loadPhotos()
        }
        .onChange(of: selectedPhotoItem) { _, newValue in
            guard let newValue else { return }

            Task {
                await uploadSelectedPhoto(newValue)
                selectedPhotoItem = nil
            }
        }
        .fullScreenCover(isPresented: $isShowingCamera) {
            ImagePicker(sourceType: .camera) { image in
                Task {
                    await uploadPhoto(image)
                }
            }
            .ignoresSafeArea()
        }
        .padding(rowPadding)
        .background(
            Color(.systemBackground)
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 24,
                style: .continuous
            )
        )
        .animation(
            .easeInOut(duration: 0.2),
            value: validation
        )
        .animation(
            .easeInOut(duration: 0.2),
            value: item.isChecked
        )
        .animation(
            .easeInOut(duration: 0.2),
            value: item.isMissing
        )
        .animation(
            .easeInOut(duration: 0.2),
            value: isPhotosExpanded
        )
        .animation(
            .easeInOut(duration: 0.2),
            value: photos.isEmpty
        )
    }

    // MARK: Header

    private var headerSection: some View {

        VStack(alignment: .leading, spacing: 10) {

            Text(item.item.itemName ?? "-")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)

            VStack(alignment: .leading, spacing: 6) {

                if item.isMissing {

                    statusBadge(
                        title: "Item Marked Missing",
                        systemImage: "exclamationmark.circle.fill"
                    )
                }

                if hasInvalidTemperature {

                    statusBadge(
                        title: "Temperature Out of Range",
                        systemImage: "thermometer.medium"
                    )
                }

                if isPreparedIncorrectly {

                    statusBadge(
                        title: "Item Not Prepared Correctly",
                        systemImage: "xmark.shield.fill"
                    )
                }
            }
        }
    }

    // MARK: Adaptive Top Section

    private var adaptiveTopSection: some View {

        Group {

            if horizontalSizeClass == .regular {

                VStack(spacing: sectionSpacing) {

                    if shouldShowDetailsCard {
                        detailsCard
                    }

                    compactValidationCard
                }

            } else {

                VStack(spacing: sectionSpacing) {

                    if shouldShowDetailsCard {
                        detailsCard
                    }
                    compactValidationCard
                }
            }
        }
    }
    // MARK: Details Card

    private var detailsCard: some View {

        VStack(alignment: .leading, spacing: 12) {

            sectionHeader(
                title: "Details",
                systemImage: "info.circle"
            )

            LazyVGrid(
                columns: detailColumns,
                alignment: .leading,
                spacing: 10
            ) {

                metadataRow(
                    icon: "clock",
                    label: "Shelf Life",
                    value: item.item.shelfLife
                )

                metadataRow(
                    icon: "square.grid.2x2",
                    label: "Pan Size",
                    value: item.item.panSize
                )

                metadataRow(
                    icon: "wrench.and.screwdriver",
                    label: "Tool",
                    value: item.item.toolName
                )

                metadataRow(
                    icon: "scalemass",
                    label: "Portion Size",
                    value: item.item.portionSize
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(cardPadding)
        .background(
            Color(.secondarySystemBackground)
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 18,
                style: .continuous
            )
        )
    }

    // MARK: Validation Card

    private var compactValidationCard: some View {

        VStack(alignment: .leading, spacing: 14) {

            sectionHeader(
                title: "Validation",
                systemImage: "checkmark.shield"
            )

            if hasDynamicCriteria {
                dynamicCriteriaSection
            } else {
                legacyValidationSection
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var hasDynamicCriteria: Bool {
        !(item.item.criterionResponses?.isEmpty ?? true)
    }

    private var legacyValidationSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            if item.item.tempTaken {
                temperatureSection
            }

            preparedCorrectlySection
            missingToggle
        }
    }

    private var dynamicCriteriaSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            if item.item.tempTaken && !hasTemperatureCriterion {
                temperatureSection
            }

            ForEach(Array((item.item.criterionResponses ?? []).indices), id: \.self) { index in
                criterionResponseSection(index: index)
            }

            if !hasMissingCriterion {
                missingToggle
            }
        }
    }

    private var hasTemperatureCriterion: Bool {
        (item.item.criterionResponses ?? []).contains { response in
            isTemperatureCriterion(response)
        }
    }

    private var hasMissingCriterion: Bool {
        (item.item.criterionResponses ?? []).contains { response in
            isMissingCriterion(response)
        }
    }

    @ViewBuilder
    private func criterionResponseSection(index: Int) -> some View {
        if let response = item.item.criterionResponses?[index] {
            let label = criterionLabel(for: response)

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    fieldLabel(title: label, systemImage: criterionIcon(for: response))

                    if response.required == true {
                        Text("Required")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.primary.opacity(0.06))
                            .clipShape(Capsule())
                    }
                }

                if isMissingCriterion(response) {
                    criterionMissingInput(index: index, response: response)
                } else if isTemperatureCriterion(response) || isNumberCriterion(response) {
                    criterionNumberInput(index: index, response: response)
                } else if isBooleanCriterion(response) {
                    criterionBooleanInput(index: index, response: response)
                } else if isPhotoCriterion(response) {
                    criterionPhotoInput(index: index, response: response)
                } else {
                    criterionTextInput(index: index, response: response)
                }

                if response.requiresCorrection == true {
                    Text("Follow-up required")
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
            .padding(14)
            .background(criterionBackground(for: response))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .disabled(isReadOnly || (item.isMissing && !isMissingCriterion(response)))
        }
    }

    private func criterionMissingInput(index: Int, response: LineCheckCriterionResponseDto) -> some View {
        Toggle("Mark Item Missing", isOn: Binding(
            get: { item.isMissing },
            set: { value in
                setBooleanAnswer(value, at: index, response: response)
            }
        ))
        .tint(.red)
        .disabled(isReadOnly)
    }

    private func criterionNumberInput(index: Int, response: LineCheckCriterionResponseDto) -> some View {
        HStack(spacing: 10) {
            TextField("", text: Binding(
                get: { numberText(for: response) },
                set: { setNumberAnswer(sanitizedNumberText($0), at: index, response: response) }
            ))
            .keyboardType(.decimalPad)
            .font(.title3.weight(.semibold))
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)

            if let unit = response.unit, !unit.isEmpty {
                Text(unit)
                    .font(.headline.weight(.medium))
                    .foregroundStyle(.secondary)
            } else if isTemperatureCriterion(response) {
                Text("°F")
                    .font(.headline.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 54)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(criterionNumberBorderColor(for: response), lineWidth: 1.5)
        }
    }

    private func criterionBooleanInput(index: Int, response: LineCheckCriterionResponseDto) -> some View {
        HStack(spacing: 12) {
            Button {
                setBooleanAnswer(true, at: index, response: response)
            } label: {
                Label("Pass", systemImage: "checkmark")
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(booleanAnswer(for: response) == true ? .green : .gray.opacity(0.35))

            Button {
                setBooleanAnswer(false, at: index, response: response)
            } label: {
                Label("Fail", systemImage: "xmark")
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(booleanAnswer(for: response) == false ? .red : .gray)
        }
    }

    private func criterionTextInput(index: Int, response: LineCheckCriterionResponseDto) -> some View {
        TextEditor(text: Binding(
            get: { response.textAnswer ?? response.notes ?? "" },
            set: { value in
                if isNotesCriterion(response) {
                    item.item.criterionResponses?[index].notes = value
                } else {
                    item.item.criterionResponses?[index].textAnswer = value
                }
            }
        ))
        .scrollContentBackground(.hidden)
        .padding(12)
        .frame(minHeight: 88)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        }
    }

    private func criterionPhotoInput(index: Int, response: LineCheckCriterionResponseDto) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Button {
                    activeCriterionPhotoResponseId = response.id
                    isShowingCamera = true
                } label: {
                    photoActionLabel(title: "Take Photo", systemImage: "camera.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(
                    isReadOnly ||
                    isUploadingPhoto ||
                    response.id == nil ||
                    !UIImagePickerController.isSourceTypeAvailable(.camera)
                )

                PhotosPicker(
                    selection: $selectedPhotoItem,
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    photoActionLabel(title: "Choose Photo", systemImage: "photo.on.rectangle")
                }
                .simultaneousGesture(
                    TapGesture().onEnded {
                        activeCriterionPhotoResponseId = response.id
                    }
                )
                .buttonStyle(.bordered)
                .disabled(isReadOnly || isUploadingPhoto || response.id == nil)
            }

            Text((response.photoCount ?? 0) > 0 ? "Photo added" : "No photo added")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func criterionLabel(for response: LineCheckCriterionResponseDto) -> String {
        response.label ?? response.criterionName ?? "Criterion"
    }

    private func criterionKey(for response: LineCheckCriterionResponseDto) -> String {
        [response.criterionType, response.responseType, response.criterionName, response.label]
            .compactMap { $0 }
            .joined(separator: " ")
            .lowercased()
    }

    private func criterionIcon(for response: LineCheckCriterionResponseDto) -> String {
        if isTemperatureCriterion(response) { return "thermometer.medium" }
        if isPhotoCriterion(response) { return "camera" }
        if isTextCriterion(response) || isNotesCriterion(response) { return "square.and.pencil" }
        if isMissingCriterion(response) { return "nosign" }
        return "checklist"
    }

    private func criterionBackground(for response: LineCheckCriterionResponseDto) -> Color {
        if response.requiresCorrection == true || failedCriterionNeedsNotes(response) {
            return Color.red.opacity(0.08)
        }

        return Color.clear
    }

    private func isMissingCriterion(_ response: LineCheckCriterionResponseDto) -> Bool {
        criterionKey(for: response).contains("missing")
    }

    private func isTemperatureCriterion(_ response: LineCheckCriterionResponseDto) -> Bool {
        let key = criterionKey(for: response)
        return key.contains("temperature") || key.contains("temp")
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

    private func numberText(for response: LineCheckCriterionResponseDto) -> String {
        if isTemperatureCriterion(response) {
            return item.temperature
        }

        guard let value = response.numberAnswer else { return "" }
        return "\(value)"
    }

    private func setNumberAnswer(_ value: String, at index: Int, response: LineCheckCriterionResponseDto) {
        if isTemperatureCriterion(response) {
            item.temperature = value
        }

        item.item.criterionResponses?[index].numberAnswer = Float(value)
        item.item.criterionResponses?[index].requiresCorrection = criterionNumberRequiresCorrection(
            value,
            response: response
        )
    }

    private func criterionNumberRequiresCorrection(
        _ value: String,
        response: LineCheckCriterionResponseDto
    ) -> Bool {
        guard !value.isEmpty else {
            return response.required == true
        }

        guard let number = Float(value) else {
            return response.required == true
        }

        if let minValue = response.minValue, number < minValue {
            return true
        }

        if let maxValue = response.maxValue, number > maxValue {
            return true
        }

        return false
    }

    private func sanitizedNumberText(_ value: String) -> String {
        var sanitized = ""
        var hasDecimal = false

        for character in value {
            if character.isNumber {
                sanitized.append(character)
            } else if character == ".", !hasDecimal {
                sanitized.append(character)
                hasDecimal = true
            }
        }

        return sanitized
    }

    private func booleanAnswer(for response: LineCheckCriterionResponseDto) -> Bool? {
        if isMissingCriterion(response) {
            return item.isMissing
        }

        return response.booleanAnswer
    }

    private func setBooleanAnswer(_ value: Bool, at index: Int, response: LineCheckCriterionResponseDto) {
        if isMissingCriterion(response) {
            item.isMissing = value

            if value {
                item.temperature = ""
                item.isChecked = nil
                item.observations = ""
                focusedField = nil
            }
        }

        item.item.criterionResponses?[index].booleanAnswer = value
        onFinalizeAction()
    }

    private func criterionNumberBorderColor(for response: LineCheckCriterionResponseDto) -> Color {
        guard isTemperatureCriterion(response) || isNumberCriterion(response) else {
            return Color.primary.opacity(0.08)
        }

        let value = numberText(for: response)
        guard !value.isEmpty else {
            return Color.primary.opacity(0.08)
        }

        if criterionNumberRequiresCorrection(value, response: response) {
            return .red.opacity(0.8)
        }

        return .green.opacity(0.8)
    }

    private func failedCriterionNeedsNotes(_ response: LineCheckCriterionResponseDto) -> Bool {
        guard response.requireNotesOnFailure == true else { return false }

        if isMissingCriterion(response) {
            return item.isMissing && item.observations.isEmpty
        }

        if isTemperatureCriterion(response) {
            let value = numberText(for: response)
            guard !value.isEmpty else { return false }

            return criterionNumberRequiresCorrection(
                value,
                response: response
            ) && item.observations.isEmpty
        }

        if isBooleanCriterion(response) {
            return booleanAnswer(for: response) == false && item.observations.isEmpty
        }

        return false
    }

    // MARK: Temperature

    private var temperatureBorderColor: Color {

        switch validation {

        case .valid:
            return Color.green.opacity(0.8)

        case .invalid:
            return Color.red.opacity(0.8)

        case .empty:
            return Color.primary.opacity(0.08)
        }
    }

    private var temperatureBorderWidth: CGFloat {

        validation == .empty ? 1 : 1.5
    }
    
    @ViewBuilder
    private var temperatureSection: some View {

        if item.item.tempTaken {

            VStack(alignment: .leading, spacing: 12) {

                fieldLabel(
                    title: "Temperature",
                    systemImage: "thermometer.medium"
                )

                HStack(spacing: 10) {

                    HStack(spacing: 6) {

                        TextField("", text: Binding(
                            get: { item.temperature },
                            set: { item.temperature = sanitizedNumberText($0) }
                        ))
                            .keyboardType(.decimalPad)
                            .focused(
                                $focusedField,
                                equals: .temperature(item.id)
                            )
                            .disabled(isReadOnly || item.isMissing)
                            .font(.title3.weight(.semibold))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)

                        Text("°F")
                            .font(.headline.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 54)
                    .background(
                        Color(.systemBackground)
                    )
                    .overlay {

                        RoundedRectangle(
                            cornerRadius: 14,
                            style: .continuous
                        )
                        .stroke(
                            temperatureBorderColor,
                            lineWidth: temperatureBorderWidth
                        )
                    }
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: 14,
                            style: .continuous
                        )
                    )

                    Button {
                        focusedField = nil
                        onFinalizeAction()
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                    .disabled(isReadOnly || item.isMissing)
                }

                if hasInvalidTemperature,
                   let min = item.item.minTemp,
                   let max = item.item.maxTemp {

                    Text("Allowed range: \(Int(min))°F – \(Int(max))°F")
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
            .padding(14)
            .background(
                hasInvalidTemperature
                ? Color.red.opacity(0.08)
                : Color.clear
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 16,
                    style: .continuous
                )
            )
        }
    }

    // MARK: Prepared Correctly

    private var preparedCorrectlySection: some View {

        VStack(alignment: .leading, spacing: 14) {

            fieldLabel(
                title: "Prepared Correctly",
                systemImage: "checklist"
            )

            HStack(spacing: 12) {

                Button {

                    item.isChecked = true
                    onFinalizeAction()

                } label: {

                    Label("Pass", systemImage: "checkmark")
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(
                    item.isChecked == true
                    ? .green
                    : .gray.opacity(0.35)
                )

                Button {

                    item.isChecked = false
                    onFinalizeAction()

                } label: {

                    Label("Fail", systemImage: "xmark")
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(
                    item.isChecked == false
                    ? .red
                    : .gray
                )
            }
        }
        .padding(14)
        .background(
            isPreparedIncorrectly
            ? Color.red.opacity(0.08)
            : Color.clear
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 16,
                style: .continuous
            )
        )
        .disabled(isReadOnly || item.isMissing)
    }

    // MARK: Missing Toggle

    private var missingToggle: some View {

        VStack(alignment: .leading, spacing: 14) {

            fieldLabel(
                title: "Item Missing",
                systemImage: "nosign"
            )

            Toggle("Mark Item Missing", isOn: $item.isMissing)
                .tint(.red)
                .disabled(isReadOnly)
                .onChange(of: item.isMissing) { _, newValue in

                    if newValue {

                        item.temperature = ""
                        item.isChecked = nil
                        item.observations = ""

                        focusedField = nil

                        onFinalizeAction()
                    }
                }
        }
        .padding(14)
        .background(
            item.isMissing
            ? Color.red.opacity(0.12)
            : Color.clear
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 16,
                style: .continuous
            )
        )
    }

    // MARK: Notes

    private var notesSection: some View {

        VStack(alignment: .leading, spacing: 14) {

            sectionHeader(
                title: "Notes",
                systemImage: "note.text"
            )

            Text(item.item.templateNotes ?? "")
                .font(.body)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color(.secondarySystemBackground)
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 18,
                style: .continuous
            )
        )
    }

    // MARK: Photos

    private var hasPhotoRelevantIssue: Bool {
        hasInvalidTemperature || isPreparedIncorrectly || item.isMissing
    }

    private var shouldShowPhotoControls: Bool {
        hasPhotoRelevantIssue || isPhotosExpanded
    }

    private var shouldShowFullPhotoSection: Bool {
        shouldShowPhotoControls || !photos.isEmpty || isLoadingPhotos || isUploadingPhoto || photoError != nil
    }

    @ViewBuilder
    private var photoArea: some View {
        if shouldShowFullPhotoSection {
            photosSection
        } else if !isReadOnly {
            compactAddPhotoButton
        }
    }

    private var compactAddPhotoButton: some View {
        Button {
            isPhotosExpanded = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "camera")
                    .font(.subheadline.weight(.semibold))
                    .symbolRenderingMode(.hierarchical)

                Text("Add Photo")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)

                Spacer()

                Image(systemName: "chevron.down")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 42)
            .frame(maxWidth: .infinity)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private var photosSection: some View {

        VStack(alignment: .leading, spacing: 14) {

            HStack(spacing: 10) {

                sectionHeader(
                    title: "Photos",
                    systemImage: "camera"
                )

                Spacer()

                if isLoadingPhotos || isUploadingPhoto {
                    ProgressView()
                }

                if !hasPhotoRelevantIssue && !isUploadingPhoto && !isReadOnly {
                    Button {
                        isPhotosExpanded.toggle()
                    } label: {
                        Image(systemName: isPhotosExpanded ? "chevron.up" : "camera.fill")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            if shouldShowPhotoControls {
                HStack(spacing: 12) {

                    Button {
                        activeCriterionPhotoResponseId = nil
                        isShowingCamera = true
                    } label: {
                        photoActionLabel(
                            title: "Take Photo",
                            systemImage: "camera.fill"
                        )
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(
                        isReadOnly ||
                        isUploadingPhoto ||
                        !UIImagePickerController.isSourceTypeAvailable(.camera)
                    )

                    PhotosPicker(
                        selection: $selectedPhotoItem,
                        matching: .images,
                        photoLibrary: .shared()
                    ) {
                        photoActionLabel(
                            title: "Choose Photo",
                            systemImage: "photo.on.rectangle"
                        )
                    }
                    .simultaneousGesture(
                        TapGesture().onEnded {
                            activeCriterionPhotoResponseId = nil
                        }
                    )
                    .buttonStyle(.bordered)
                    .disabled(isReadOnly || isUploadingPhoto)
                }
            }

            if let photoError {
                Text(photoError)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            if photos.isEmpty && !isLoadingPhotos {
                Text("No photos added")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(photos) { photo in
                            photoThumbnail(photo)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding(cardPadding)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func photoActionLabel(
        title: String,
        systemImage: String
    ) -> some View {
        Label(title, systemImage: systemImage)
            .font(.subheadline.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Rectangle())
    }

    private func photoThumbnail(_ photo: LineCheckPhotoDto) -> some View {

        Group {
            if let urlString = photo.url,
               let url = URL(string: urlString) {

                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()

                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()

                    case .failure:
                        photoPlaceholder

                    @unknown default:
                        EmptyView()
                    }
                }
            } else {
                photoPlaceholder
            }
        }
        .frame(width: 84, height: 84)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        }
    }

    private var photoPlaceholder: some View {
        Image(systemName: "photo")
            .font(.title2)
            .foregroundStyle(.secondary)
    }

    // MARK: Correction History

    private var shouldShowCorrectionHistory: Bool {
        isReadOnly && (
            item.item.isCorrected == true ||
            hasDetailValue(item.item.correctiveNotes) ||
            !correctivePhotos.isEmpty
        )
    }

    private var correctivePhotos: [LineCheckPhotoDto] {
        photos.filter { $0.photoType == .corrective }
    }

    private var correctionHistorySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(
                title: "Correction",
                systemImage: "checkmark.seal"
            )

            Label("Marked corrected", systemImage: "checkmark.circle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.green)

            if let correctedMetaText {
                Text(correctedMetaText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let notes = item.item.correctiveNotes,
               !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Correction Notes")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text(notes)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if !correctivePhotos.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Corrective Photos")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(correctivePhotos) { photo in
                                photoThumbnail(photo)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .padding(cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.green.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.green.opacity(0.18), lineWidth: 1)
        }
    }

    private var correctedMetaText: String? {
        var parts: [String] = []

        if let correctedByName = item.item.correctedByName,
           !correctedByName.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty {
            parts.append("By \(correctedByName)")
        }

        if let correctedAt = item.item.correctedAt {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            parts.append(formatter.string(from: correctedAt))
        }

        return parts.isEmpty ? nil : parts.joined(separator: " - ")
    }

    // MARK: Observations

    private var observationsSection: some View {

        VStack(alignment: .leading, spacing: 14) {

            sectionHeader(
                title: "Observations",
                systemImage: "square.and.pencil"
            )

            TextEditor(text: $item.observations)
                .disabled(isReadOnly)
                .focused(
                    $focusedField,
                    equals: .observation(item.id)
                )
                .scrollContentBackground(.hidden)
                .padding(12)
                .frame(
                    minHeight: horizontalSizeClass == .regular
                    ? 84
                    : 76
                )
                .background(
                    Color(.systemBackground)
                )
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: 16,
                        style: .continuous
                    )
                )
                .overlay {

                    RoundedRectangle(
                        cornerRadius: 16,
                        style: .continuous
                    )
                    .stroke(
                        Color.primary.opacity(0.08),
                        lineWidth: 1
                    )
                }
        }
        .padding(cardPadding)
        .background(
            Color(.secondarySystemBackground)
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 18,
                style: .continuous
            )
        )
    }

    // MARK: Photo Actions

    private func loadPhotos() async {
        guard let lineCheckItemId else { return }

        isLoadingPhotos = true
        photoError = nil

        do {
            photos = try await LineCheckPhotoApi.shared.getPhotos(
                lineCheckItemId: lineCheckItemId
            )
        } catch {
            photoError = error.localizedDescription
        }

        isLoadingPhotos = false
    }

    private func uploadSelectedPhoto(_ photoItem: PhotosPickerItem) async {
        do {
            guard let data = try await photoItem.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                photoError = "Could not read selected image."
                return
            }

            await uploadPhoto(image)
        } catch {
            photoError = error.localizedDescription
        }
    }

    private func uploadPhoto(_ image: UIImage) async {
        guard let lineCheckItemId else {
            photoError = "Line check item is missing an ID."
            return
        }

        guard let imageData = jpegData(from: image) else {
            photoError = "Could not prepare image for upload."
            return
        }

        isUploadingPhoto = true
        photoError = nil

        do {
            let criterionResponseId = activeCriterionPhotoResponseId

            _ = try await LineCheckPhotoApi.shared.uploadPhoto(
                lineCheckItemId: lineCheckItemId,
                imageData: imageData,
                fileName: "line-check-\(lineCheckItemId)-\(UUID().uuidString).jpg",
                photoType: criterionResponseId == nil ? .item : .criterion,
                notes: item.observations,
                criterionResponseId: criterionResponseId
            )

            if let criterionResponseId,
               let index = item.item.criterionResponses?.firstIndex(where: { $0.id == criterionResponseId }) {
                let currentCount = item.item.criterionResponses?[index].photoCount ?? 0
                item.item.criterionResponses?[index].photoCount = currentCount + 1
                activeCriterionPhotoResponseId = nil
            }

            photos = try await LineCheckPhotoApi.shared.getPhotos(
                lineCheckItemId: lineCheckItemId
            )
        } catch {
            photoError = error.localizedDescription
        }

        isUploadingPhoto = false
    }

    private func jpegData(from image: UIImage) -> Data? {
        let maxDimension: CGFloat = 900
        let maxUploadBytes = 600 * 1024
        let size = image.size
        let largestDimension = max(size.width, size.height)
        let targetSize: CGSize

        if largestDimension > maxDimension {
            let scale = maxDimension / largestDimension
            targetSize = CGSize(
                width: size.width * scale,
                height: size.height * scale
            )
        } else {
            targetSize = size
        }

        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let resizedImage = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }

        let compressionQualities: [CGFloat] = [0.72, 0.62, 0.52, 0.42, 0.32]
        var smallestData: Data?

        for quality in compressionQualities {
            guard let data = resizedImage.jpegData(compressionQuality: quality) else {
                continue
            }

            smallestData = data

            if data.count <= maxUploadBytes {
                return data
            }
        }

        return smallestData
    }

    private var lineCheckItemId: String? {
        item.item.id ?? item.id.uuidString
    }

    // MARK: Helpers

    private var hasNotes: Bool {

        !(item.item.templateNotes?.isEmpty ?? true)
    }

    private var shouldShowDetailsCard: Bool {
        isFoodPrepItem || hasDetailValue(item.item.shelfLife)
        || hasDetailValue(item.item.panSize)
        || hasDetailValue(item.item.toolName)
        || hasDetailValue(item.item.portionSize)
    }

    private var isFoodPrepItem: Bool {
        (item.item.itemType ?? "FOOD_PREP").uppercased() == "FOOD_PREP"
    }

    private func hasDetailValue(_ value: String?) -> Bool {
        guard let value else { return false }
        return !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func sectionHeader(
        title: String,
        systemImage: String
    ) -> some View {

        Label(title, systemImage: systemImage)
            .font(.headline.weight(.semibold))
            .foregroundStyle(.primary)
            .symbolRenderingMode(.hierarchical)
    }

    private func fieldLabel(
        title: String,
        systemImage: String
    ) -> some View {

        Label(title, systemImage: systemImage)
            .font(.footnote.weight(.medium))
            .foregroundStyle(.secondary)
            .symbolRenderingMode(.hierarchical)
    }

    private func statusBadge(
        title: String,
        systemImage: String
    ) -> some View {

        Label(title, systemImage: systemImage)
            .font(.footnote.weight(.medium))
            .foregroundStyle(.red)
    }

    @ViewBuilder
    private func metadataRow(
        icon: String,
        label: String,
        value: String?
    ) -> some View {

        if let value, !value.isEmpty {

            HStack(alignment: .center, spacing: 12) {

                Image(systemName: icon)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .symbolRenderingMode(.hierarchical)
                    .frame(width: 18)

                Text(label)
                    .foregroundStyle(.secondary)

                Spacer(minLength: 20)

                Text(value)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.trailing)
            }
            .font(.subheadline)
        }
    }
}
