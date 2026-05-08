import SwiftUI

struct LineCheckStationSection: View {

    let stationName: String

    @Binding var items: [LineCheckItemState]

    @FocusState.Binding var focusedField: LineCheckField?
    
    

    @State private var isExpanded = true

    // MARK: PROGRESS

    private var completedItems: Int {

        items.filter {
            $0.isMissing ||
            !$0.temperature.isEmpty ||
            $0.isChecked != nil
        }
        .count
    }

    private var totalItems: Int {
        items.count
    }

    private var progress: Double {

        guard totalItems > 0 else {
            return 0
        }

        return Double(completedItems) / Double(totalItems)
    }

    private var isComplete: Bool {
        completedItems == totalItems && totalItems > 0
    }

    private var progressColor: Color {

        if progress >= 1 {
            return .green
        }

        if progress > 0.7 {
            return .orange
        }

        return .red
    }

    // MARK: BODY

    var body: some View {

        VStack(spacing: 12) {

            stationHeader

            VStack(spacing: 12) {

                ForEach(items.indices, id: \.self) { index in

                    LineCheckItemRow(
                        item: $items[index],
                        focusedField: $focusedField,
                        onFinalizeAction: collapseIfComplete
                    )
                }
            }
            .frame(maxHeight: isExpanded ? nil : 0)
            .opacity(isExpanded ? 1 : 0)
            .clipped()
        }
        .animation(.easeInOut(duration: 0.22), value: isExpanded)
    }

    // MARK: HEADER

    private var stationHeader: some View {

        Button {

            withAnimation {
                isExpanded.toggle()
            }

        } label: {

            VStack(alignment: .leading, spacing: 10) {

                HStack(spacing: 8) {

                    Label("Station:", systemImage: "fork.knife.circle")
                        .foregroundColor(.secondary)

                    Text(stationName)
                        .font(.headline)

                    Spacer()

                    HStack(spacing: 8) {

                        Text("\(completedItems)/\(totalItems)")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text(
                            progress.formatted(
                                .percent.precision(.fractionLength(0))
                            )
                        )
                        .font(.caption.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(progressColor.opacity(0.10))
                        .foregroundColor(progressColor)
                        .clipShape(Capsule())

                        Image(systemName:
                                isExpanded
                              ? "chevron.down.circle.fill"
                              : "chevron.right.circle.fill"
                        )
                        .foregroundColor(.blue)
                    }
                }

                ProgressView(value: progress)
                    .tint(progressColor)
            }
            .padding()
            .background(.background)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
        }
        .buttonStyle(.plain)
    }
    
    private func collapseIfComplete() {

        if isComplete {

            withAnimation(.easeInOut(duration: 0.22)) {
                isExpanded = false
            }
        }
    }
}

