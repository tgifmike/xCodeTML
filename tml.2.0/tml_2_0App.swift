import SwiftUI
import GoogleSignIn

@main
struct tml_2_0App: App {

    @StateObject private var sessionManager = SessionManager()
    @StateObject private var appSettings = AppSettings()
    @StateObject private var offlineSyncCoordinator = OfflineSyncCoordinator.shared
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

                    if sessionManager.session != nil {

                        AccountPickerView()

                    } else {

                        LoginView(onLoginSuccess: { newSession in

                            sessionManager.session = newSession

                            Task {
                                await offlineSyncCoordinator.syncNow()
                            }

                            autoLogoutManager.startTimer(
                                interval: appSettings.autoLogoutInterval
                            ) {
                                sessionManager.logout(clearSavedSession: false)
                            }
                        })
                    }
                }
            }

            // MARK: User Activity Tracking

//            .contentShape(Rectangle())

//            .simultaneousGesture(
//                TapGesture().onEnded {
//
//                    guard sessionManager.session != nil else {
//                        return
//                    }
//
//                    autoLogoutManager.resetTimer(
//                        interval: appSettings.autoLogoutInterval
//                    ) {
//                        sessionManager.logout()
//                    }
//                }
//            )

            // MARK: Splash

            .task {

                offlineSyncCoordinator.startMonitoring()

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

                    Task {
                        await offlineSyncCoordinator.syncNow()
                    }

                    autoLogoutManager.startTimer(
                        interval: appSettings.autoLogoutInterval
                    ) {
                        sessionManager.logout(clearSavedSession: false)
                    }

                } else {

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
}
