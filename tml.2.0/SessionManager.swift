//
//  SessioinManager.swift
//  tml.2.0
//
//  Created by mike on 4/14/26.
//

import SwiftUI
import Combine

@MainActor
class SessionManager: ObservableObject {

    @Published var session: UserSession? = nil

    func logout() {
        session = nil
    }
}
