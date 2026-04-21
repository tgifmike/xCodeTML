//
//  AuthProvider.swift
//  tml.2.0
//
//  Created by mike on 4/21/26.
//

enum AuthProvider: String {

    case google
    case apple
    case demo

    var displayName: String {

        switch self {

        case .google:
            return "Google"

        case .apple:
            return "Apple"

        case .demo:
            return "Demo Mode"
        }
    }
}
