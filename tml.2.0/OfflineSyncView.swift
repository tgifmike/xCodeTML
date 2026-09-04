import SwiftUI

struct OfflineSyncView: View {

    @EnvironmentObject var offlineSyncCoordinator: OfflineSyncCoordinator

    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Status")
                    Spacer()
                    Label(
                        offlineSyncCoordinator.isOnline ? "Online" : "Offline",
                        systemImage: offlineSyncCoordinator.isOnline ? "wifi" : "wifi.slash"
                    )
                    .foregroundStyle(offlineSyncCoordinator.isOnline ? Color.green : Color.orange)
                }

                LabeledContent("Pending Checks", value: "\(offlineSyncCoordinator.pendingLineCheckCount)")
                LabeledContent("Pending Photos", value: "\(offlineSyncCoordinator.pendingPhotoCount)")

                if let lastSyncAttemptAt = offlineSyncCoordinator.lastSyncAttemptAt {
                    LabeledContent("Last Attempt", value: formattedSyncDate(lastSyncAttemptAt))
                }

                if let lastSyncAt = offlineSyncCoordinator.lastSyncAt {
                    LabeledContent("Last Sync", value: formattedSyncDate(lastSyncAt))
                }
            } header: {
                Text("Status")
            } footer: {
                Text(offlineSyncCoordinator.statusText)
            }

            Section {
                if let summary = offlineSyncCoordinator.lastSyncSummary {
                    Label(summary, systemImage: "checkmark.circle")
                        .foregroundStyle(.green)
                }

                if let error = offlineSyncCoordinator.lastErrorMessage {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                }

                Button {
                    Task {
                        await offlineSyncCoordinator.syncNow()
                    }
                } label: {
                    if offlineSyncCoordinator.isSyncing {
                        HStack {
                            ProgressView()
                            Text("Syncing")
                        }
                    } else {
                        Label("Sync Now", systemImage: "arrow.triangle.2.circlepath")
                    }
                }
                .disabled(offlineSyncCoordinator.isSyncing || offlineSyncCoordinator.pendingCount == 0)
            } header: {
                Text("Actions")
            }
        }
        .navigationTitle("Offline Sync")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func formattedSyncDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
