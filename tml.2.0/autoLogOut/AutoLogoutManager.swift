//
//  AutoLogoutManager.swift
//  tml.2.0
//
//  Created by mike on 5/13/26.
//


import Foundation

final class AutoLogoutManager {

    private var logoutTask: Task<Void, Never>?

    func startTimer(
        interval: AutoLogoutInterval,
        onLogout: @escaping () -> Void
    ) {

        logoutTask?.cancel()

        guard let seconds = interval.timeInterval else {
            return
        }

        logoutTask = Task {

            do {

                try await Task.sleep(
                    for: .seconds(seconds)
                )

                await MainActor.run {
                    onLogout()
                }

            } catch {
                // cancelled
            }
        }
    }

    func resetTimer(
        interval: AutoLogoutInterval,
        onLogout: @escaping () -> Void
    ) {

        startTimer(
            interval: interval,
            onLogout: onLogout
        )
    }

    func stop() {
        logoutTask?.cancel()
    }
}
