////
////  SettingsView.swift
////  tml.2.0
////
////  Created by mike on 4/21/26.
////
//
//import SwiftUI
//
//struct SettingsView: View {
//
//    @EnvironmentObject var appSettings: AppSettings
//    @EnvironmentObject var sessionManager: SessionManager
//    
//    var body: some View {
//
//        ScrollView {
//
//            VStack(spacing: 16) {
//
//                completionModeCard
//
//                Divider()
//
//                autoLogoutCard
//                
//                Spacer()
//            }
//            .padding()
//        }
//        .navigationTitle("Settings")
//        .navigationBarTitleDisplayMode(.inline)
//    }
//}
//
//private extension SettingsView {
//
//    var completionModeCard: some View {
//
//        VStack(alignment: .leading, spacing: 12) {
//
//            Text("Line Check Completion Mode")
//                .font(.headline)
//            
//            if !sessionManager.canEditCompletionMode {
//
//                Label(
//                    "Manager access required",
//                    systemImage: "lock.fill"
//                )
//                .font(.caption)
//                .foregroundStyle(.secondary)
//            }
//
//            ForEach(LineCheckCompletionMode.allCases) { mode in
//
//                Button {
//
//                    if sessionManager.canEditCompletionMode {
//                        appSettings.completionMode = mode
//                    }
//
//                } label: {
//
//                    HStack {
//
//                        VStack(alignment: .leading, spacing: 4) {
//
//                            Text(mode.title)
//                                .font(.subheadline.weight(.semibold))
//
//                            Text(mode.description)
//                                .font(.caption)
//                                .foregroundStyle(.secondary)
//                        }
//                        
//
//                        Spacer()
//
//                        if appSettings.completionMode == mode {
//
//                            Image(systemName: "checkmark.circle.fill")
//                                .foregroundStyle(.blue)
//                        }
//                    }
//                    .padding()
//                    .background(
//                        RoundedRectangle(cornerRadius: 14)
//                            .fill(Color(.systemBackground))
//                    )
//                    .overlay(
//                        RoundedRectangle(cornerRadius: 14)
//                            .stroke(Color.black.opacity(0.05))
//                    )
//                }
//                .buttonStyle(.plain)
//                .disabled(!sessionManager.canEditCompletionMode)
//                .opacity(sessionManager.canEditCompletionMode ? 1 : 0.45)
//            }
//        }
//    }
//    
//    var autoLogoutCard: some View {
//
//        VStack(alignment: .leading, spacing: 12) {
//
//            Text("Auto Logout")
//                .font(.headline)
//
//            Text("Automatically sign out after inactivity.")
//                .font(.caption)
//                .foregroundStyle(.secondary)
//
//            ForEach(AutoLogoutInterval.allCases) { interval in
//
//                Button {
//
//                    appSettings.autoLogoutInterval = interval
//
//                } label: {
//
//                    HStack {
//
//                        Text(interval.title)
//                            .font(.subheadline.weight(.semibold))
//
//                        Spacer()
//
//                        if appSettings.autoLogoutInterval == interval {
//
//                            Image(systemName: "checkmark.circle.fill")
//                                .foregroundStyle(.blue)
//                        }
//                    }
//                    .padding()
//                    .background(
//                        RoundedRectangle(cornerRadius: 14)
//                            .fill(Color(.systemBackground))
//                    )
//                    .overlay(
//                        RoundedRectangle(cornerRadius: 14)
//                            .stroke(Color.black.opacity(0.05))
//                    )
//                }
//                .buttonStyle(.plain)
//            }
//        }
//    }
//}
//import SwiftUI
//
//struct SettingsView: View {
//
//    @EnvironmentObject var appSettings: AppSettings
//    @EnvironmentObject var sessionManager: SessionManager
//
//    var body: some View {
//
//        Form {
//
//            // MARK: Completion Mode
//
//            Section {
//
//                ForEach(LineCheckCompletionMode.allCases) { mode in
//
//                    Button {
//
//                        guard sessionManager.canEditCompletionMode else { return }
//
//                        appSettings.completionMode = mode
//
//                    } label: {
//
//                        HStack {
//
//                            VStack(alignment: .leading, spacing: 4) {
//
//                                Text(mode.title)
//                                    .font(.subheadline.weight(.semibold))
//
//                                Text(mode.description)
//                                    .font(.caption)
//                                    .foregroundStyle(.secondary)
//                            }
//
//                            Spacer()
//
//                            if appSettings.completionMode == mode {
//
//                                Image(systemName: "checkmark")
//                                    .foregroundStyle(.blue)
//                                    .font(.system(size: 14, weight: .semibold))
//                            }
//                        }
//                    }
//                    .disabled(!sessionManager.canEditCompletionMode)
//                    .opacity(sessionManager.canEditCompletionMode ? 1 : 0.5)
//                }
//
//            } header: {
//                Text("Line Check")
//            } footer: {
//                if !sessionManager.canEditCompletionMode {
//                    Text("Manager access required to change completion mode.")
//                }
//            }
//
//            // MARK: Auto Logout
//
//            Section {
//
//                ForEach(AutoLogoutInterval.allCases) { interval in
//
//                    Button {
//
//                        appSettings.autoLogoutInterval = interval
//
//                    } label: {
//
//                        HStack {
//
//                            Text(interval.title)
//
//                            Spacer()
//
//                            if appSettings.autoLogoutInterval == interval {
//                                Image(systemName: "checkmark")
//                                    .foregroundStyle(.blue)
//                                    .font(.system(size: 14, weight: .semibold))
//                            }
//                        }
//                    }
//                }
//
//            } header: {
//                Text("Security")
//            } footer: {
//                Text("Automatically logs out after inactivity.")
//            }
//        }
//        .navigationTitle("Settings")
//        .navigationBarTitleDisplayMode(.inline)
//    }
//}
import SwiftUI

struct SettingsView: View {

    @EnvironmentObject var appSettings: AppSettings
    @EnvironmentObject var sessionManager: SessionManager
    @EnvironmentObject var offlineSyncCoordinator: OfflineSyncCoordinator

    var body: some View {

        Form {

            // MARK: Line Check Completion Mode
            Section {
                
                Picker("Completion Mode", selection: $appSettings.completionMode) {

                    ForEach(LineCheckCompletionMode.allCases) { mode in
                        VStack(alignment: .leading) {
                            Text(mode.title)
                            Text(mode.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .tag(mode)
                    }
                }
                .pickerStyle(.inline) // or .menu if you prefer compact UI
                .disabled(!sessionManager.canEditCompletionMode)

            } header: {
                Text("Line Check")
            } footer: {
                if !sessionManager.canEditCompletionMode {
                    Text("Manager access required to change completion mode.")
                }
            }

            Section {
                Toggle(
                    "Show Line Check History",
                    isOn: Binding(
                        get: { appSettings.canViewLineCheckHistory },
                        set: { appSettings.setLineCheckHistoryPermission($0) }
                    )
                )
            } header: {
                Text("History")
            } footer: {
                Text("Controls whether Line Check History appears on the location Dashboard.")
            }

            Section {
                LabeledContent("Status") {
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
                Text("Offline Sync")
            } footer: {
                Text(offlineSyncCoordinator.statusText)
            }

            // MARK: Auto Logout
            Section {

                Picker("Auto Logout", selection: $appSettings.autoLogoutInterval) {

                    ForEach(AutoLogoutInterval.allCases) { interval in
                        Text(interval.title)
                            .tag(interval)
                    }
                }
                .pickerStyle(.menu) // best UX for settings
            } header: {
                Text("Security")
            } footer: {
                Text("Automatically logs out after inactivity.")
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func formattedSyncDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
