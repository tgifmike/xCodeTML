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
        case .empty: return .gray.opacity(0.5)
        case .valid: return .green
        case .invalid: return .red
        }
    }
    
    // MARK: - Metadata Row
    @ViewBuilder
    private func metadataRow(icon: String, label: String, value: String?, color: Color) -> some View {
        if let value, !value.isEmpty {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .frame(width: 18)
                Text(label)
                    .font(.subheadline)
                    .foregroundColor(color)
                Spacer()
                Text(value)
                    .font(.subheadline)
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
            
            // MARK: - Metadata + Right Panel Inline
            HStack(alignment: .top, spacing: 12) {
                
                // LEFT — Metadata Grid (~70%)
                VStack(alignment: .leading, spacing: 6) {
                    metadataRow(icon: "clock", label: "Shelf Life", value: item.shelfLife, color: .orange)
                    metadataRow(icon: "square.grid.2x2", label: "Pan Size", value: item.panSize, color: .green)
                    metadataRow(icon: "wrench.and.screwdriver", label: "Tool", value: item.toolName, color: .blue)
                    metadataRow(icon: "scalemass", label: "Portion Size", value: item.portionSize, color: .purple)
                }
                .padding(10)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .frame(maxWidth: .infinity)
                
                // RIGHT — Temperature OR Checkmark (~30%)
                VStack(spacing: 6) {
                    
                    if item.tempTaken {
                        // Temperature Inline
                        HStack(spacing: 6) {
                            Image(systemName: "thermometer")
                                .foregroundColor(.blue)
                            Text("Temperature")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                            TextField("°F", text: $input.temperature)
                                .keyboardType(.decimalPad)
                                .focused($focusedField, equals: .temperature(input.id))
                                .padding(6)
                                .background(Color(.systemBackground))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(borderColor, lineWidth: 1.5)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .frame(width: 80)
                        }
                        if validation == .invalid,
                           let min = item.minTemp,
                           let max = item.maxTemp {
                            Text("Allowed \(Int(min))°F – \(Int(max))°F")
                                .font(.caption2)
                                .foregroundColor(.red)
                        }
                    }
                    
                    if item.checkMark {
                        // Checkmark Inline
                        Button {
                            input.isChecked.toggle()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle")
                                    .foregroundColor(.green)
                                Text("Item Prepared Correctly")
                                    .font(.subheadline)
                                    .foregroundColor(.green)
                                Image(systemName: input.isChecked ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(input.isChecked ? .green : .red)
                                    .font(.title2)
                                
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    
                }
                .frame(width: 320) // ~30% width
            }
            
            // MARK: - Notes
            if let notes = item.templateNotes, !notes.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Image(systemName: "note.text")
                            .foregroundColor(.gray)
                            .frame(width: 18)
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
            
            // MARK: - Observations
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.pencil")
                        .foregroundColor(.gray)
                        .frame(width: 18)
                    
                    Text("Observations")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
                
                TextEditor(text: $input.observations)
                    .focused($focusedField, equals: .observation(input.id))
                    .frame(minHeight: 70)
                    .padding(8)
                    .background(Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(
                                focusedField == .observation(input.id) ? Color.blue : Color.secondary.opacity(0.5),
                                lineWidth: 1
                            )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }
}
