//
//  AutoLogoutInterval.swift
//  tml.2.0
//
//  Created by mike on 5/13/26.
//

import Foundation

enum AutoLogoutInterval: String, CaseIterable, Identifiable {

    case oneMinute
    case fiveMinutes
    case thirtyMinutes
    case sixtyMinutes
    case never

    var id: String { rawValue }

    var title: String {

        switch self {
        case .oneMinute:
            return "1 Minute"

        case .fiveMinutes:
            return "5 Minutes"

        case .thirtyMinutes:
            return "30 Minutes"

        case .sixtyMinutes:
            return "60 Minutes"

        case .never:
            return "Never"
        }
    }

    var timeInterval: TimeInterval? {

        switch self {
        case .oneMinute:
            return 60

        case .fiveMinutes:
            return 300

        case .thirtyMinutes:
            return 1800

        case .sixtyMinutes:
            return 3600

        case .never:
            return nil
        }
    }
}
