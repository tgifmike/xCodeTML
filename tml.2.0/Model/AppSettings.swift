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

    @AppStorage("autoLogoutInterval")
    private var autoLogoutRawValue: String = AutoLogoutInterval.never.rawValue

    @Published var autoLogoutInterval: AutoLogoutInterval = .never

    init() {
        self.autoLogoutInterval =
            AutoLogoutInterval(rawValue: autoLogoutRawValue) ?? .never
    }

    func setAutoLogout(_ newValue: AutoLogoutInterval) {
        autoLogoutRawValue = newValue.rawValue
        autoLogoutInterval = newValue
    }
}
