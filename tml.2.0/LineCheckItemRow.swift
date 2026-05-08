import SwiftUI

struct LineCheckItemRow: View {

    @Binding var item: LineCheckItemState
    @FocusState.Binding var focusedField: LineCheckField?
    let onFinalizeAction: () -> Void

    private var validation: TempValidation {

        guard !item.temperature.isEmpty,
              let value = Float(item.temperature),
              let min = item.item.minTemp,
              let max = item.item.maxTemp else {
            return .empty
        }

        return (value >= min && value <= max) ? .valid : .invalid
    }

    private enum TempValidation {
        case empty, valid, invalid
    }

    private var borderColor: Color {
        switch validation {
        case .empty: return .gray.opacity(0.4)
        case .valid: return .green
        case .invalid: return .red
        }
    }

    var body: some View {

        VStack(alignment: .leading, spacing: 12) {

            Text(item.item.itemName ?? "-")
                .font(.headline)
                .foregroundColor(.blue)

            metadataSection

            controlPanel

            notesSection

            observationsSection
        }
        .padding(.vertical, 8)
    }

    // MARK: CONTROL

    private var controlPanel: some View {

        VStack(alignment: .leading, spacing: 10) {

            temperatureSection
            preparedCorrectlySection
            missingToggle
        }
        .padding(12)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: TEMPERATURE

    @ViewBuilder
    private var temperatureSection: some View {

        if item.item.tempTaken {

            HStack(alignment: .top) {

                Text("Temperature")
                    .font(.subheadline)
                    .foregroundColor(.blue)

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {

//                    TextField("°F", text: $item.temperature)
//                        .keyboardType(.decimalPad)
//                        .focused($focusedField, equals: .temperature(item.id))
//                        .padding(6)
//                        .background(Color(.systemBackground))
//                        .overlay(
//                            RoundedRectangle(cornerRadius: 8)
//                                .stroke(borderColor, lineWidth: 1.5)
//                        )
//                        .clipShape(RoundedRectangle(cornerRadius: 8))
//                        .frame(width: 90)
//                        .disabled(item.isMissing)
                    
                    HStack(spacing: 8) {

                        TextField("°F", text: $item.temperature)
                            .keyboardType(.decimalPad)
                            .focused($focusedField, equals: .temperature(item.id))
                            .padding(6)
                            .background(Color(.systemBackground))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(borderColor, lineWidth: 1.5)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .frame(width: 90)
                            .disabled(item.isMissing)
                            .submitLabel(.done)
                            .onSubmit {
                                focusedField = nil
                                onFinalizeAction()
                            }

                        Button {
                            focusedField = nil
                            onFinalizeAction()
                        } label: {
                            Text("Done")
                                .font(.caption.bold())
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.15))
                                .foregroundColor(.blue)
                                .clipShape(Capsule())
                        }
                    }

                    if case .invalid = validation,
                       let min = item.item.minTemp,
                       let max = item.item.maxTemp {

                        Text("Allowed Range \(Int(min))°F – \(Int(max))°F")
                            .font(.caption2)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
        }
    }

    // MARK: CHECK
    @ViewBuilder
    private var preparedCorrectlySection: some View {

        if item.item.checkMark {

            HStack {

                Text("Item Prepared Correctly?")
                    .font(.subheadline)
                    .foregroundColor(.green)

                Spacer()

                Button {
                    item.isChecked = true
                    onFinalizeAction()
                } label: {
                    Label("Yes", systemImage: "checkmark.circle.fill")
                        .foregroundColor(item.isChecked == true ? .green : .gray)
                }

                Button {
                    item.isChecked = false
                    onFinalizeAction()
                } label: {
                    Label("No", systemImage: "xmark.circle.fill")
                        .foregroundColor(item.isChecked == false ? .red : .gray)
                }
            }
            .disabled(item.isMissing)
        }
    }

    // MARK: MISSING
    @ViewBuilder
    private var missingToggle: some View {

        HStack {
            Text("Item Missing?")
                .font(.subheadline)
                .foregroundColor(.red)

            Spacer()

            Toggle("", isOn: $item.isMissing)
                .labelsHidden()
                .tint(.red)
                .onChange(of: item.isMissing) { _, newValue in
                    if newValue {
                        item.temperature = ""
                        item.isChecked = nil
                        item.observations = ""
                        
                        onFinalizeAction()
                    }
                }
        }
    }
    
    // MARK: NOTES

    @ViewBuilder
    private var notesSection: some View {

        if let notes = item.item.templateNotes,
           !notes.isEmpty {

            VStack(alignment: .leading, spacing: 8) {

                HStack(spacing: 6) {

                    Image(systemName: "note.text")
                        .foregroundColor(.gray)

                    Text("Notes")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()
                }

                Text(notes)
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: OBSERVATIONS

    private var observationsSection: some View {

        VStack(alignment: .leading, spacing: 6) {

            HStack {
                Image(systemName: "square.and.pencil")
                    .foregroundColor(.gray)

                Text("Observations")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()
            }

            TextEditor(text: $item.observations)
                .focused($focusedField, equals: .observation(item.id))
                .frame(minHeight: 70)
                .padding(8)
                .background(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.4))
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    // MARK: METADATA
    @ViewBuilder
    private var metadataSection: some View {

        let hasAny =
            !(item.item.shelfLife?.isEmpty ?? true) ||
            !(item.item.panSize?.isEmpty ?? true) ||
            !(item.item.toolName?.isEmpty ?? true) ||
            !(item.item.portionSize?.isEmpty ?? true)

        if hasAny {

            VStack(alignment: .leading, spacing: 8) {

                metadataRow(icon: "clock", label: "Shelf Life", value: item.item.shelfLife, color: .orange)
                metadataRow(icon: "square.grid.2x2", label: "Pan Size", value: item.item.panSize, color: .green)
                metadataRow(icon: "wrench.and.screwdriver", label: "Tool", value: item.item.toolName, color: .blue)
                metadataRow(icon: "scalemass", label: "Portion Size", value: item.item.portionSize, color: .purple)
            }
            .padding(12)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    @ViewBuilder
    private func metadataRow(icon: String, label: String, value: String?, color: Color) -> some View {

        if let value, !value.isEmpty {

            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)

                Text(label)
                    .foregroundColor(color)

                Spacer()

                Text(value)
            }
        }
    }
}

