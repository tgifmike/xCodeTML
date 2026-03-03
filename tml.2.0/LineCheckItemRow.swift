import SwiftUI

struct LineCheckItemRow: View {

    @Binding var input: LineCheckItemInput
    @FocusState.Binding var focusedField: LineCheckField?

    private var item: LineCheckItemDto { input.item }

    // MARK: - Temperature Validation

    private enum TempValidation { case empty, valid, invalid }

    private var validation: TempValidation {
        guard !input.temperature.isEmpty,
              let value = Float(input.temperature),
              let min = item.minTemp,
              let max = item.maxTemp
        else { return .empty }

        return (value >= min && value <= max) ? .valid : .invalid
    }

    private var borderColor: Color {
        switch validation {
        case .empty:
            return .gray.opacity(0.5)
        case .valid:
            return .green
        case .invalid:
            return .red
        }
    }

    // MARK: - Semantic Metadata Row

    @ViewBuilder
    private func metadataRow(
        icon: String,
        label: String,
        value: String?,
        color: Color
    ) -> some View {

        if let value, !value.isEmpty {
            HStack(spacing: 8) {

                Image(systemName: icon)
                    .foregroundColor(color)
                    .frame(width: 18)

                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Text(value)
                    .font(.caption)
                    .fontWeight(.medium)
            }
        }
    }

    // MARK: - Body

    var body: some View {

        VStack(alignment: .leading, spacing: 12) {

            // Item Name
            Text(item.itemName ?? "-")
                .font(.headline)

            // Metadata Grid
            VStack(alignment: .leading, spacing: 8) {

                metadataRow(
                    icon: "clock",
                    label: "Shelf Life",
                    value: item.shelfLife,
                    color: .orange
                )

                metadataRow(
                    icon: "square.grid.2x2",
                    label: "Pan Size",
                    value: item.panSize,
                    color: .green
                )

                metadataRow(
                    icon: "wrench.and.screwdriver",
                    label: "Tool",
                    value: item.toolName,
                    color: .blue
                )

                metadataRow(
                    icon: "scalemass",
                    label: "Portion",
                    value: item.portionSize,
                    color: .purple
                )

                metadataRow(
                    icon: "note.text",
                    label: "Notes",
                    value: item.templateNotes,
                    color: .gray
                )
            }
            .padding(10)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Temperature Input
            if item.tempTaken {
                VStack(alignment: .leading, spacing: 4) {

                    TextField("Temperature °F", text: $input.temperature)
                        .keyboardType(.decimalPad)
                        .focused($focusedField, equals: .temperature(input.id))
                        .padding(10)
                        .background(Color(.systemBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(borderColor, lineWidth: 1.5)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    if validation == .invalid,
                       let min = item.minTemp,
                       let max = item.maxTemp {

                        Text("Allowed: \(Int(min)) – \(Int(max))°F")
                            .font(.caption2)
                            .foregroundColor(.red)
                    }
                }
            }

            // Observations
            TextEditor(text: $input.observations)
                .focused($focusedField, equals: .observation(input.id))
                .frame(minHeight: 70)
                .padding(8)
                .background(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(
                            focusedField == .observation(input.id)
                            ? Color.blue
                            : Color.secondary.opacity(0.5),
                            lineWidth: 1
                        )
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
    }
}
