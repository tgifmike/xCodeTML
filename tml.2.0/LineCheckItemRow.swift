import SwiftUI
//import Foundation

struct LineCheckItemRow: View {
    
    @Binding var input: LineCheckItemInput
    @FocusState.Binding var focusedField: LineCheckField?
    
    @Environment(\.horizontalSizeClass) private var sizeClass
    
    private var item: LineCheckItemDto { input.item }
    
    // MARK: Temperature Validation
    
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
    
    // MARK: Body
    
    var body: some View {
        
        VStack(alignment: .leading, spacing: 14) {
            
            Text(item.itemName ?? "-")
                .font(.headline)
                .foregroundColor(.blue)
            
            adaptiveLayout
            
            notesSection
            
            observationsSection
        }
        .padding(.vertical, 8)
    }
}

extension LineCheckItemRow {
    
    // MARK: Adaptive Layout
    
    @ViewBuilder
    private var adaptiveLayout: some View {
        
        if sizeClass == .compact {
            
            VStack(spacing: 12) {
                metadataPanel
                controlPanel
            }
            
        } else {
            
            HStack(alignment: .top, spacing: 12) {
                metadataPanel
                controlPanel
            }
        }
    }
    
    // MARK: Metadata Panel
    
    private var metadataPanel: some View {
        
        VStack(alignment: .leading, spacing: 8) {
            
            metadataRow(icon: "clock", label: "Shelf Life", value: item.shelfLife, color: .orange)
            metadataRow(icon: "square.grid.2x2", label: "Pan Size", value: item.panSize, color: .green)
            metadataRow(icon: "wrench.and.screwdriver", label: "Tool", value: item.toolName, color: .blue)
            metadataRow(icon: "scalemass", label: "Portion Size", value: item.portionSize, color: .purple)
        }
        .padding(12)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .frame(maxWidth: .infinity)
    }
    
    // MARK: Control Panel
    
    private var controlPanel: some View {
        
        VStack(alignment: .leading, spacing: 10) {
            
            temperatureSection
            
            preparedCorrectlySection
            
            missingToggle
        }
        .padding(12)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .frame(maxWidth: .infinity)
    }
    
    // MARK: Temperature Input
    
    private var temperatureSection: some View {
        
        VStack(alignment: .leading, spacing: 6) {
            
            if item.tempTaken {
                
                HStack(spacing: 8) {
                    
                    Image(systemName: "thermometer")
                        .foregroundColor(.blue)
                    
                    Text("Temperature")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                    
                    Spacer()
                    
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
                        .frame(width: 90)
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
    }
    
    // MARK: Prepared Correctly
    
    private var preparedCorrectlySection: some View {
        
        VStack(alignment: .leading, spacing: 8) {
            
            if item.checkMark {
                
                Text("Item Prepared Correctly?")
                    .font(.subheadline)
                    .foregroundColor(.green)
                
                HStack(spacing: 18) {
                    
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
    }
    
    // MARK: Missing Toggle
    
    private var missingToggle: some View {
        
        HStack {
            
            Text("Item Missing")
                .font(.subheadline)
                .foregroundColor(.red)
            
            Spacer()
            
            Toggle("", isOn: $input.isMissing)
                .labelsHidden()
                .tint(.red)
        }
        .onChange(of: input.isMissing) { oldValue, newValue in
            if newValue && !oldValue {
                input.isChecked = nil
                input.temperature = ""
            }
        }
    }
    
    // MARK: Metadata Row
    
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
    
    // MARK: Notes
    
    private var notesSection: some View {
        
        Group {
            
            if let notes = item.templateNotes, !notes.isEmpty {
                
                VStack(alignment: .leading, spacing: 6) {
                    
                    HStack {
                        
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
    }
    
    // MARK: Observations
    
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
    }
}
