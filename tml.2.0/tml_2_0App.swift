import SwiftUI
import GoogleSignIn

@main
struct tml_2_0App: App {

    @StateObject private var sessionManager = SessionManager()
    @StateObject private var appSettings = AppSettings()
    @StateObject private var offlineSyncCoordinator = OfflineSyncCoordinator.shared
    @StateObject private var pinStore = OfflinePinDeviceStore.shared
    private let autoLogoutManager = AutoLogoutManager()
    private let currentEULAVersion = 1
    @State private var showSplash = true
    @State private var isCheckingEULA = false
    @State private var isAcceptingEULA = false
    @State private var eulaErrorMessage: String?
    @State private var backendAcceptedEULAVersion: Int?
    @State private var acceptedEULAVersion = 0

    init() {

        GIDSignIn.sharedInstance.configuration = GIDConfiguration(
            clientID:
            "2850496933-mb4fvrsps45mrjh46lvpfvjomgpco8vh.apps.googleusercontent.com",

            serverClientID:
            "2850496933-i622ohq8a2h26jv89l8mmb10jn4isdmh.apps.googleusercontent.com"
        )
    }

    var body: some Scene {

        WindowGroup {

            Group {

                if showSplash {

                    SplashView()

                } else {

                    if let session = sessionManager.session {

                        if isCheckingEULA {

                            ProgressView("Checking agreement...")

                        } else if needsEULAAgreement {

                            EULAAgreementView(
                                isSubmitting: isAcceptingEULA,
                                errorMessage: eulaErrorMessage,
                                onAccept: acceptEULA,
                                onDecline: declineEULA
                            )

                        } else if let enrollment = pinStore.defaultEnrollment,
                                  let locationId = enrollment.locationId {

                            EnrolledDeviceDashboardView(
                                accountId: enrollment.accountId,
                                locationId: locationId
                            )

                        } else if let accountId = session.accountId,
                                  let locationId = session.locationId {

                            EnrolledDeviceDashboardView(
                                accountId: accountId,
                                locationId: locationId
                            )

                        } else {

                            AccountPickerView()
                        }

                    } else if sessionManager.savedSession != nil && pinStore.hasUsablePinLogin {

                        OfflinePinLoginView(
                            onLoginSuccess: handleLoginSuccess,
                            showsCancelButton: false
                        )

                    } else {

                        LoginView(onLoginSuccess: handleLoginSuccess)
                    }
                }
            }

            // MARK: Splash

            .task {

                offlineSyncCoordinator.startMonitoring()

                if sessionManager.session != nil {
                    await refreshEULAAcceptanceStatus()
                }

                offlineSyncCoordinator.setLineCheckSyncEnabled(isLineCheckSyncAllowed)

                if isLineCheckSyncAllowed {
                    await offlineSyncCoordinator.syncIfPossible(reason: "app-start")
                }

                try? await Task.sleep(
                    for: .seconds(2)
                )

                withAnimation(.easeOut(duration: 0.4)) {
                    showSplash = false
                }
            }

            // MARK: Session Change

            .onChange(of: sessionManager.session != nil) { _, loggedIn in

                if loggedIn {

                    Task {
                        await refreshEULAAcceptanceStatus()

                        if hasAcceptedCurrentEULA {
                            startAuthenticatedSessionWork()
                        } else {
                            offlineSyncCoordinator.setLineCheckSyncEnabled(false)
                        }
                    }

                } else {

                    acceptedEULAVersion = 0
                    backendAcceptedEULAVersion = nil
                    eulaErrorMessage = nil
                    offlineSyncCoordinator.setLineCheckSyncEnabled(false)
                    autoLogoutManager.stop()
                }
            }
            
            .onChange(of: appSettings.autoLogoutInterval) { _, newValue in

                guard isLineCheckSyncAllowed else { return }

                autoLogoutManager.startTimer(interval: newValue) {
                    sessionManager.logout(clearSavedSession: false)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: APIClient.sessionExpiredNotification)) { _ in
                sessionManager.logout(clearSavedSession: false)
            }
        }
        .environmentObject(sessionManager)
        .environmentObject(appSettings)
        .environmentObject(offlineSyncCoordinator)
    }

    private var effectiveAcceptedEULAVersion: Int {
        max(acceptedEULAVersion, backendAcceptedEULAVersion ?? 0)
    }

    private var hasAcceptedCurrentEULA: Bool {
        effectiveAcceptedEULAVersion >= currentEULAVersion
    }

    private var needsEULAAgreement: Bool {
        sessionManager.session != nil && !hasAcceptedCurrentEULA
    }

    private var isLineCheckSyncAllowed: Bool {
        sessionManager.session != nil && hasAcceptedCurrentEULA
    }

    private func handleLoginSuccess(_ newSession: UserSession) {
        acceptedEULAVersion = locallyAcceptedEULAVersion(for: newSession.userId)
        backendAcceptedEULAVersion = nil
        eulaErrorMessage = nil
        sessionManager.session = newSession
    }

    private func acceptEULA() {
        guard !isAcceptingEULA else { return }

        isAcceptingEULA = true
        eulaErrorMessage = nil

        Task {
            do {
                try await EULAApi.shared.accept(version: currentEULAVersion)
                cacheEULAAcceptance(version: currentEULAVersion)
                acceptedEULAVersion = currentEULAVersion
                backendAcceptedEULAVersion = currentEULAVersion
                isAcceptingEULA = false
                startAuthenticatedSessionWork()
            } catch {
                isAcceptingEULA = false
                eulaErrorMessage = "Could not save agreement. Please check your connection and try again."
            }
        }
    }

    private func declineEULA() {
        GIDSignIn.sharedInstance.signOut()
        acceptedEULAVersion = 0
        backendAcceptedEULAVersion = nil
        eulaErrorMessage = nil
        offlineSyncCoordinator.setLineCheckSyncEnabled(false)
        sessionManager.logout(clearSavedSession: true)
    }

    private func refreshEULAAcceptanceStatus() async {
        guard let session = sessionManager.session else { return }

        acceptedEULAVersion = locallyAcceptedEULAVersion(for: session.userId)
        isCheckingEULA = true
        eulaErrorMessage = nil

        do {
            let status = try await EULAApi.shared.getAcceptanceStatus()
            if let acceptedVersion = status.acceptedVersion {
                backendAcceptedEULAVersion = acceptedVersion
                acceptedEULAVersion = max(acceptedEULAVersion, acceptedVersion)
                cacheEULAAcceptance(version: acceptedVersion)
            } else if status.hasAcceptedCurrentVersion {
                backendAcceptedEULAVersion = currentEULAVersion
                acceptedEULAVersion = max(acceptedEULAVersion, currentEULAVersion)
                cacheEULAAcceptance(version: currentEULAVersion)
            } else {
                backendAcceptedEULAVersion = 0
            }
        } catch {
            backendAcceptedEULAVersion = acceptedEULAVersion
        }

        isCheckingEULA = false
    }

    private func locallyAcceptedEULAVersion(for userId: String) -> Int {
        UserDefaults.standard.integer(forKey: eulaAcceptanceKey(for: userId))
    }

    private func cacheEULAAcceptance(version: Int) {
        guard let userId = sessionManager.session?.userId else { return }
        UserDefaults.standard.set(version, forKey: eulaAcceptanceKey(for: userId))
    }

    private func eulaAcceptanceKey(for userId: String) -> String {
        "acceptedEULAVersion:\(userId)"
    }

    private func startAuthenticatedSessionWork() {
        offlineSyncCoordinator.setLineCheckSyncEnabled(true)

        Task {
            await offlineSyncCoordinator.syncNow()
        }

        autoLogoutManager.startTimer(
            interval: appSettings.autoLogoutInterval
        ) {
            sessionManager.logout(clearSavedSession: false)
        }
    }
}
