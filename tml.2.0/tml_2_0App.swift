import SwiftUI
import GoogleSignIn

@main
struct tml_2_0App: App {

    @StateObject private var sessionManager = SessionManager()
    @StateObject private var appSettings = AppSettings()
    @StateObject private var offlineSyncCoordinator = OfflineSyncCoordinator.shared
    @StateObject private var pinStore = OfflinePinDeviceStore.shared
    private let autoLogoutManager = AutoLogoutManager()
    @State private var showSplash = true

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

                        if let enrollment = pinStore.defaultEnrollment,
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
                offlineSyncCoordinator.setLineCheckSyncEnabled(isLineCheckSyncAllowed)

                if sessionManager.session != nil {
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

                    offlineSyncCoordinator.setLineCheckSyncEnabled(isLineCheckSyncAllowed)

                    Task {
                        await offlineSyncCoordinator.syncNow()
                    }

                    autoLogoutManager.startTimer(
                        interval: appSettings.autoLogoutInterval
                    ) {
                        sessionManager.logout(clearSavedSession: false)
                    }

                } else {

                    offlineSyncCoordinator.setLineCheckSyncEnabled(false)
                    autoLogoutManager.stop()
                }
            }
            
            .onChange(of: appSettings.autoLogoutInterval) { _, newValue in

                guard sessionManager.session != nil else { return }

                autoLogoutManager.startTimer(interval: newValue) {
                    sessionManager.logout(clearSavedSession: false)
                }
            }
        }
        .environmentObject(sessionManager)
        .environmentObject(appSettings)
        .environmentObject(offlineSyncCoordinator)
    }

    private var isLineCheckSyncAllowed: Bool {
        sessionManager.session != nil
    }

    private func handleLoginSuccess(_ newSession: UserSession) {
        sessionManager.session = newSession
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
