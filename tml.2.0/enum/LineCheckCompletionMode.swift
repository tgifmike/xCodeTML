//
//  LineCheckCompletionMode.swift
//  tml.2.0
//
//  Created by mike on 4/20/26.
//

enum LineCheckCompletionMode: String, CaseIterable, Identifiable {

    case requireAllItemsCompleted
    case allowIncompleteLineCheck

    var id: String { rawValue }

    var title: String {

        switch self {

        case .requireAllItemsCompleted:
            return "Require All Items Completed"

        case .allowIncompleteLineCheck:
            return "Allow Incomplete Save"
        }
    }

    var description: String {

        switch self {

        case .requireAllItemsCompleted:
            return "User must complete every checklist item before saving."

        case .allowIncompleteLineCheck:
            return "User can save even if some checklist items remain incomplete."
        }
    }
}
