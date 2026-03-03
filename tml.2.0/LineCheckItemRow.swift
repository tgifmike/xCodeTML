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
        case .empty: return .gray
        case .valid: return .green
        case .invalid: return .red
        }
    }

    // MARK: - Body
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            // Item name
            Text(item.itemName ?? "-")
                .font(.headline)

            // Metadata grid
            VStack(alignment: .leading, spacing: 6) {
                HStack { Text("Shelf Life:").font(.caption).foregroundColor(.secondary); Spacer(); Text(item.shelfLife ?? "-").font(.caption) }
                HStack { Text("Pan Size:").font(.caption).foregroundColor(.secondary); Spacer(); Text(item.panSize ?? "-").font(.caption) }
                HStack { Text("Tool:").font(.caption).foregroundColor(.secondary); Spacer(); Text(item.toolName ?? "-").font(.caption) }
                HStack { Text("Portion:").font(.caption).foregroundColor(.secondary); Spacer(); Text(item.portionSize ?? "-").font(.caption) }
                if let notes = item.templateNotes, !notes.isEmpty {
                    HStack { Text("Notes:").font(.caption).foregroundColor(.secondary); Spacer(); Text(notes).font(.caption) }
                }
            }
            .padding(8)
            .background(.quaternary.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            // Temperature field with persistent validation
            if item.tempTaken {
                VStack(alignment: .leading, spacing: 4) {
                    TextField("°F", text: $input.temperature)
                        .keyboardType(.decimalPad)
                        .focused($focusedField, equals: .temperature(input.id))
                        .textFieldStyle(.roundedBorder)
                        .padding(4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(borderColor, lineWidth: 1.5)
                        )

                    // Show allowed range if invalid
                    if validation == .invalid, let min = item.minTemp, let max = item.maxTemp {
                        Text("Allowed: \(Int(min)) – \(Int(max))°F")
                            .font(.caption2)
                            .foregroundColor(.red)
                    }
                }
            }

            // Observations
            TextEditor(text: $input.observations)
                .focused($focusedField, equals: .observation(input.id))
                .frame(minHeight: 60)
                .padding(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(focusedField == .observation(input.id) ? Color.blue : Color.secondary.opacity(0.5), lineWidth: 1)
                )
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
    }
}
