import SwiftUI

struct LineCheckHistoryView: View {

    let locationId: String
    let locationName: String
    let accountName: String

    @State private var lineChecks: [LineCheckDto] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        content
            .navigationTitle("Line Check History")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await loadLineChecks()
            }
            .refreshable {
                await loadLineChecks()
            }
    }
}

private extension LineCheckHistoryView {

    @ViewBuilder
    var content: some View {
        if isLoading {
            ProgressView("Loading history...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let errorMessage {
            ContentUnavailableView(
                "Unable to Load History",
                systemImage: "exclamationmark.triangle",
                description: Text(errorMessage)
            )
        } else if lineChecks.isEmpty {
            ContentUnavailableView(
                "No Completed Line Checks",
                systemImage: "clock.arrow.circlepath",
                description: Text("Completed line checks for this location will appear here.")
            )
        } else {
            lineCheckList
        }
    }

    var lineCheckList: some View {
        List(lineChecks) { lineCheck in
            NavigationLink {
                LineCheckDetailView(
                    lineCheckId: lineCheck.id,
                    locationId: locationId,
                    locationName: locationName,
                    accountName: accountName,
                    isReadOnly: true
                )
            } label: {
                LineCheckHistoryRow(lineCheck: lineCheck)
            }
        }
        .listStyle(.plain)
    }

    func loadLineChecks() async {
        isLoading = true
        errorMessage = nil

        do {
            lineChecks = try await LineCheckApi.shared.getCompletedLineChecksByLocation(
                locationId: locationId
            )
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

private struct LineCheckHistoryRow: View {

    let lineCheck: LineCheckDto

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(primaryDateText)
                        .font(.headline)

                    Text(lineCheck.username ?? "Unknown user")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(durationText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.10))
                    .clipShape(Capsule())
            }

            HStack(spacing: 14) {
                Label("\(lineCheck.stations.count) stations", systemImage: "square.grid.2x2")
                Label("\(issueCount) issues", systemImage: issueCount == 0 ? "checkmark.circle" : "exclamationmark.triangle")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
    }

    var primaryDateText: String {
        guard let completedAt = lineCheck.completedAt ?? lineCheck.checkTime else {
            return "Unknown date"
        }

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: completedAt)
    }

    var durationText: String {
        guard let durationSeconds = lineCheck.durationSeconds else {
            return "--"
        }

        let minutes = durationSeconds / 60
        let seconds = durationSeconds % 60

        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        }

        return "\(seconds)s"
    }

    var issueCount: Int {
        lineCheck.stations.reduce(0) { total, station in
            total + station.items.filter { item in
                item.isMissing == true ||
                isOutOfTemperatureRange(item) ||
                hasIncorrectPrep(item)
            }.count
        }
    }

    func isOutOfTemperatureRange(_ item: LineCheckItemDto) -> Bool {
        guard let temperature = item.temperature else {
            return false
        }

        if let minTemp = item.minTemp, temperature < minTemp {
            return true
        }

        if let maxTemp = item.maxTemp, temperature > maxTemp {
            return true
        }

        return false
    }

    func hasIncorrectPrep(_ item: LineCheckItemDto) -> Bool {
        guard item.checkMark else {
            return false
        }

        return item.itemChecked == false
    }
}
