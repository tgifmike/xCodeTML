import SwiftUI

struct LineCheckItemRow: View {

    @Binding var item: LineCheckItemState
    @FocusState.Binding var focusedField: LineCheckField?

    let onFinalizeAction: () -> Void

    @Environment(\.horizontalSizeClass)
    private var horizontalSizeClass

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

    // MARK: Body

    var body: some View {

        VStack(alignment: .leading, spacing: 16) {

            headerSection

            adaptiveTopSection

            if hasNotes {
                notesSection
            }

            observationsSection
        }
        .padding(18)
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

                VStack(spacing: 18) {

                    HStack(alignment: .top, spacing: 18) {

                        detailsCard
                            .frame(maxWidth: .infinity)

                        compactValidationCard
                            .frame(maxWidth: .infinity)
                    }

                    missingCard
                }

            } else {

                VStack(spacing: 18) {

                    detailsCard
                    compactValidationCard
                    missingCard
//                    missingToggle
                }
            }
        }
    }
    // MARK: Details Card

    private var detailsCard: some View {

        VStack(alignment: .leading, spacing: 20) {

            sectionHeader(
                title: "Details",
                systemImage: "info.circle"
            )

            VStack(spacing: 14) {

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
        .padding(18)
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

            if item.item.tempTaken {
                temperatureSection
            }

            if item.item.checkMark {
                preparedCorrectlySection
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
    
    //MARK: missing card
    private var missingCard: some View {

        VStack(alignment: .leading, spacing: 14) {

            sectionHeader(
                title: "Item Missing",
                systemImage: "exclamationmark.triangle"
            )

            VStack(alignment: .leading, spacing: 12) {

                Toggle("Mark Item Missing", isOn: $item.isMissing)
                    .tint(.red)
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
        }
        .padding(16)
        .background(
            item.isMissing
            ? Color.red.opacity(0.12)
            : Color(.secondarySystemBackground)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    // MARK: Temperature

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

                        TextField("", text: $item.temperature)
                            .keyboardType(.decimalPad)
                            .focused(
                                $focusedField,
                                equals: .temperature(item.id)
                            )
                            .disabled(item.isMissing)
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
                            hasInvalidTemperature
                            ? Color.red.opacity(0.7)
                            : Color.primary.opacity(0.08),
                            lineWidth: hasInvalidTemperature ? 1.5 : 1
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

    @ViewBuilder
    private var preparedCorrectlySection: some View {

        if item.item.checkMark {

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

                        Label("Yes", systemImage: "checkmark")
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

                        Label("No", systemImage: "xmark")
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
            .disabled(item.isMissing)
        }
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
        .padding(18)
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

    // MARK: Observations

    private var observationsSection: some View {

        VStack(alignment: .leading, spacing: 14) {

            sectionHeader(
                title: "Observations",
                systemImage: "square.and.pencil"
            )

            TextEditor(text: $item.observations)
                .focused(
                    $focusedField,
                    equals: .observation(item.id)
                )
                .scrollContentBackground(.hidden)
                .padding(12)
                .frame(
                    minHeight: horizontalSizeClass == .regular
                    ? 90
                    : 110
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
        .padding(18)
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

    // MARK: Helpers

    private var hasNotes: Bool {

        !(item.item.templateNotes?.isEmpty ?? true)
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
