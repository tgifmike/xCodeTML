import SwiftUI

struct CheckBoxRow: View {

    let title: String
    let systemImage: String
    @Binding var isChecked: Bool

    var body: some View {

        VStack(alignment: .leading, spacing: 6) {

            // TOP LABEL (icon + text)
            Label(title, systemImage: systemImage)
                .font(.caption)
                .foregroundStyle(Color.green)

            // CHECK CONTROL
            Button {
                withAnimation(.snappy) {
                    isChecked.toggle()
                }
            } label: {

                HStack {
                    Image(systemName: isChecked
                          ? "checkmark.circle.fill"
                          : "circle")
                        .font(.system(size: 26))
                        .foregroundStyle(isChecked ? .green : .red)
                        .symbolEffect(.bounce, value: isChecked)

                    Text(isChecked ? "Correct!" : "Tap to mark prepared correctly")
                        .font(.caption)
                        .foregroundStyle(.primary)

                    Spacer()
                }
                .padding(.vertical, 6)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
}
