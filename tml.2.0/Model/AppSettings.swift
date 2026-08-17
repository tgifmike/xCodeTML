//
//  AppSettings.swift
//  tml.2.0
//
//  Created by mike on 4/21/26.
//


import SwiftUI
import Combine

final class AppSettings: ObservableObject {

    @Published var completionMode: LineCheckCompletionMode = .requireAllItemsCompleted

    @AppStorage("canViewLineCheckHistory")
    private var canViewLineCheckHistoryRawValue: Bool = true

    @Published var canViewLineCheckHistory: Bool = true

    @AppStorage("autoLogoutInterval")
    private var autoLogoutRawValue: String = AutoLogoutInterval.never.rawValue

    @Published var autoLogoutInterval: AutoLogoutInterval = .never

    init() {
        self.autoLogoutInterval =
            AutoLogoutInterval(rawValue: autoLogoutRawValue) ?? .never
        self.canViewLineCheckHistory = canViewLineCheckHistoryRawValue
    }

    func setLineCheckHistoryPermission(_ newValue: Bool) {
        canViewLineCheckHistoryRawValue = newValue
        canViewLineCheckHistory = newValue
    }

    func setAutoLogout(_ newValue: AutoLogoutInterval) {
        autoLogoutRawValue = newValue.rawValue
        autoLogoutInterval = newValue
    }
}
