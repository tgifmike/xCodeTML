import SwiftUI

struct LineCheckItemRow: View {
    
    @Binding var input: LineCheckItemInput
    @FocusState.Binding var focusedField: LineCheckField?
    
    private var item: LineCheckItemDto { input.item }
    
    // Track previous state to detect ON toggle
   // @State private var previousMissing: Bool = false
    
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
    
    // MARK: - Metadata Row Helper
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
                .foregroundColor(Color(.blue))
            
            // Main Row: Metadata + Right Panel
            HStack(alignment: .top, spacing: 12) {
                // LEFT Metadata
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
                
                // RIGHT Panel: Temperature + Check + Toggle
                VStack(spacing: 6) {
                    // Temperature, Prepared Correctly buttons, Item Missing toggle
                    // Temperature Input
                    if item.tempTaken {
                        VStack(alignment: .leading, spacing: 4) {
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
                                    .disabled(input.isMissing)
                            }
                            
                            if validation == .invalid,
                               let min = item.minTemp,
                               let max = item.maxTemp {
                                Text("Allowed Range \(Int(min))°F – \(Int(max))°F")
                                    .font(.caption2)
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    
                    // Prepared Correctly Buttons
                    if item.checkMark {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Item Prepared Correctly?")
                                .font(.subheadline)
                                .foregroundColor(.green)
                            
                            HStack(spacing: 16) {
                                Button {
                                    input.isChecked = true
                                } label: {
                                    Label("Yes", systemImage: "checkmark.circle.fill")
                                        .foregroundColor(input.isChecked == true ? .green : .gray)
                                }
                                .buttonStyle(.plain)
                                .disabled(input.isMissing)
                                
                                Button {
                                    input.isChecked = false
                                } label: {
                                    Label("No", systemImage: "xmark.circle.fill")
                                        .foregroundColor(input.isChecked == false ? .red : .gray)
                                }
                                .buttonStyle(.plain)
                                .disabled(input.isMissing)
                            }
                        }
                    }
                    
                    // Item Missing Toggle
                    HStack(spacing: 12) {
                        Text("Item Missing")
                            .font(.subheadline)
                            .foregroundColor(.red)
                        
                        Toggle("", isOn: $input.isMissing)
                            .labelsHidden()
                            .tint(.red)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 10)
                    .frame(width: 320)
                    .onChange(of: input.isMissing) { oldValue, newValue in
                        if newValue && !oldValue {
                            input.isChecked = nil
                            input.temperature = ""
                        }
                    }
                }
                .frame(width: 320)
            } // <-- end HStack
            
            // NOW Notes Section: BELOW the row
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

            // Observations Section: BELOW notes
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
//        .onAppear {
//            previousMissing = input.isMissing
//        }
    }
}
