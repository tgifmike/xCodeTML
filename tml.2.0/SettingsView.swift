import SwiftUI
import UIKit

struct SettingsView: View {

    var pinEnrollmentAccount: Account? = nil

    @EnvironmentObject var appSettings: AppSettings
    @EnvironmentObject var sessionManager: SessionManager
    @StateObject private var pinStore = OfflinePinDeviceStore.shared
    @StateObject private var offlineNavigationStore = OfflineAccountLocationStore.shared
    @State private var isShowingPinAccessConfirmation = false
    @State private var isShowingDeviceAccessMessage = false
    @State private var isUpdatingPinAccess = false
    @State private var isLoadingPinEnrollmentLocations = false
    @State private var deviceAccessMessage = ""
    @State private var pinEnrollmentLocations: [Location] = []
    @State private var selectedPinEnrollmentLocationId = ""
    @State private var pinEnrollmentLocationError: String?

    var body: some View {
        Form {
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
                .pickerStyle(.inline)
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
                VStack(alignment: .leading, spacing: 6) {
                    Picker("Auto Logout", selection: $appSettings.autoLogoutInterval) {
                        ForEach(AutoLogoutInterval.allCases) { interval in
                            Text(interval.title)
                                .tag(interval)
                        }
                    }
                    .pickerStyle(.menu)

                    Text("After inactivity, return to the account or employee PIN screen without clearing saved access.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if canManagePinAccess {
                    VStack(alignment: .leading, spacing: 6) {
                        if !pinStore.hasDeviceEnrollment {
                            Picker("PIN Location", selection: $selectedPinEnrollmentLocationId) {
                                if pinEnrollmentLocations.isEmpty {
                                    Text(isLoadingPinEnrollmentLocations ? "Loading locations" : "No locations available")
                                        .tag("")
                                } else {
                                    Text("Select location")
                                        .tag("")

                                    ForEach(pinEnrollmentLocations) { location in
                                        Text(location.name)
                                            .tag(location.id)
                                    }
                                }
                            }
                            .pickerStyle(.menu)
                            .disabled(isLoadingPinEnrollmentLocations || pinEnrollmentLocations.isEmpty)

                            if let pinEnrollmentLocationError {
                                Text(pinEnrollmentLocationError)
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                        }

                        Button(role: pinStore.hasDeviceEnrollment ? .destructive : nil) {
                            isShowingPinAccessConfirmation = true
                        } label: {
                            if isUpdatingPinAccess {
                                HStack {
                                    ProgressView()
                                    Text(pinStore.hasDeviceEnrollment ? "Revoking PIN Access" : "Enrolling iPad")
                                }
                            } else {
                                Label(pinAccessActionTitle, systemImage: pinAccessActionImage)
                            }
                        }
                        .disabled(isUpdatingPinAccess || !canSubmitPinAccessUpdate)

                        Text(pinAccessDescription)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Security")
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: pinEnrollmentAccount?.id ?? "") {
            await loadPinEnrollmentLocationsIfNeeded()
        }
        .confirmationDialog(
            pinAccessConfirmationTitle,
            isPresented: $isShowingPinAccessConfirmation,
            titleVisibility: .visible
        ) {
            Button(pinAccessActionTitle, role: pinStore.hasDeviceEnrollment ? .destructive : nil) {
                Task {
                    await updatePinAccess()
                }
            }

            Button("Cancel", role: .cancel) { }
        } message: {
            Text(pinAccessConfirmationMessage)
        }
        .alert("iPad Access", isPresented: $isShowingDeviceAccessMessage) {
            Button("OK") { }
        } message: {
            Text(deviceAccessMessage)
        }
    }

    private var canManagePinAccess: Bool {
        guard sessionManager.session?.authProvider != .pin else {
            return false
        }

        let role = sessionManager.session?.appRole.uppercased()
        return role == "MANAGER" || role == "ADMIN"
    }

    private var canSubmitPinAccessUpdate: Bool {
        if pinStore.hasDeviceEnrollment {
            return true
        }

        return pinEnrollmentAccount != nil && !selectedPinEnrollmentLocationId.isEmpty
    }

    private var selectedPinEnrollmentLocation: Location? {
        pinEnrollmentLocations.first { $0.id == selectedPinEnrollmentLocationId }
    }

    private var pinAccessActionTitle: String {
        pinStore.hasDeviceEnrollment ? "Revoke PIN Access for This iPad" : "Enroll This iPad for PIN Access"
    }

    private var pinAccessActionImage: String {
        pinStore.hasDeviceEnrollment ? "key.slash.fill" : "key.fill"
    }

    private var pinAccessDescription: String {
        if pinStore.hasDeviceEnrollment {
            return "Disable employee PIN login on this iPad."
        }

        guard let account = pinEnrollmentAccount else {
            return "Open Settings from an account screen to enroll this iPad for PIN access."
        }

        if let location = selectedPinEnrollmentLocation {
            return "Enable employee PIN login for \(location.name) under \(account.name)."
        }

        return "Choose the location this iPad should use for employee PIN access."
    }

    private var pinAccessConfirmationTitle: String {
        pinStore.hasDeviceEnrollment ? "Revoke PIN Access?" : "Enroll This iPad?"
    }

    private var pinAccessConfirmationMessage: String {
        if pinStore.hasDeviceEnrollment {
            return "This iPad will no longer be able to use employee PIN login until a manager enrolls it again. You will be signed out after revoking access."
        }

        let locationName = selectedPinEnrollmentLocation?.name ?? "the selected location"
        let accountName = pinEnrollmentAccount?.name ?? "this account"
        return "This iPad will be enabled for employee PIN login at \(locationName) under \(accountName)."
    }

    private func loadPinEnrollmentLocationsIfNeeded() async {
        guard canManagePinAccess, !pinStore.hasDeviceEnrollment, let account = pinEnrollmentAccount else {
            pinEnrollmentLocations = []
            selectedPinEnrollmentLocationId = ""
            pinEnrollmentLocationError = nil
            return
        }

        isLoadingPinEnrollmentLocations = true
        pinEnrollmentLocationError = nil
        defer { isLoadingPinEnrollmentLocations = false }

        do {
            let locations = try await LocationApi.shared.getLocationsForAccount(accountId: account.id)
                .filter(\.active)
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

            pinEnrollmentLocations = locations
            offlineNavigationStore.cacheLocations(locations, accountId: account.id)
            if !locations.contains(where: { $0.id == selectedPinEnrollmentLocationId }) {
                selectedPinEnrollmentLocationId = locations.first?.id ?? ""
            }
        } catch {
            pinEnrollmentLocations = []
            selectedPinEnrollmentLocationId = ""
            pinEnrollmentLocationError = "Could not load locations: \(error.localizedDescription)"
        }
    }

    private func updatePinAccess() async {
        isUpdatingPinAccess = true
        defer { isUpdatingPinAccess = false }

        do {
            if pinStore.hasDeviceEnrollment {
                try await pinStore.revokeDeviceAccess()
                sessionManager.logout()
            } else {
                guard let account = pinEnrollmentAccount else {
                    deviceAccessMessage = "Open Settings from an account screen to enroll this iPad for PIN access."
                    isShowingDeviceAccessMessage = true
                    return
                }

                guard let location = selectedPinEnrollmentLocation else {
                    deviceAccessMessage = "Choose a location before enrolling this iPad for PIN access."
                    isShowingDeviceAccessMessage = true
                    return
                }

                try await pinStore.enrollOrRefresh(
                    accountId: account.id,
                    locationId: location.id,
                    deviceName: UIDevice.current.name
                )
                deviceAccessMessage = "This iPad is enrolled for employee PIN access at \(location.name)."
                isShowingDeviceAccessMessage = true
            }
        } catch {
            let action = pinStore.hasDeviceEnrollment ? "revoke" : "enroll"
            deviceAccessMessage = "Could not \(action) iPad PIN access: \(error.localizedDescription)"
            isShowingDeviceAccessMessage = true
        }
    }
}
