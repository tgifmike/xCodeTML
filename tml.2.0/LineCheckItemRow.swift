
import SwiftUI

struct LineCheckItemRow: View {

    @Binding var input: LineCheckItemInput
    @FocusState.Binding var focusedField: LineCheckField?

    private var item: LineCheckItemDto { input.item }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            
            // Item name
            Text(item.itemName ?? "-")
                .font(.headline)

            // Metadata grid
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Shelf Life:").font(.caption).foregroundColor(.secondary)
                    Spacer()
                    Text(item.shelfLife ?? "-").font(.caption)
                }
                HStack {
                    Text("Pan Size:").font(.caption).foregroundColor(.secondary)
                    Spacer()
                    Text(item.panSize ?? "-").font(.caption)
                }
                HStack {
                    Text("Tool:").font(.caption).foregroundColor(.secondary)
                    Spacer()
                    Text(item.toolName ?? "-").font(.caption)
                }
                HStack {
                    Text("Portion:").font(.caption).foregroundColor(.secondary)
                    Spacer()
                    Text(item.portionSize ?? "-").font(.caption)
                }
                if let notes = item.templateNotes, !notes.isEmpty {
                    HStack {
                        Text("Notes:").font(.caption).foregroundColor(.secondary)
                        Spacer()
                        Text(notes).font(.caption)
                    }
                }
            }
            .padding(8)
            .background(.quaternary.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            // Temperature field
            if item.tempTaken {
                TextField("°F", text: $input.temperature)
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: .temperature(input.id))
                    .textFieldStyle(.roundedBorder)
            }

            // Observations
            TextEditor(text: $input.observations)
                .focused($focusedField, equals: .observation(input.id))
                .frame(minHeight: 60)
                .padding(4)
                .onTapGesture {
                    focusedField = .observation(input.id)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.5))
                )
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
    }
}
