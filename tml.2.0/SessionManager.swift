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

    @Published var session: UserSession? = nil {
        didSet {
            APIClient.shared.jwt = session?.jwt

            if preserveSavedSessionOnNextClear && session == nil {
                preserveSavedSessionOnNextClear = false
                return
            }

            saveSession()
        }
    }

    private let sessionStorageKey = "savedUserSession"
    private let userDefaults: UserDefaults
    private var preserveSavedSessionOnNextClear = false

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        session = loadSession()
        APIClient.shared.jwt = session?.jwt
    }
    
    var canEditCompletionMode: Bool {
        ["MANAGER", "ADMIN"].contains(session?.appRole ?? "")
    }

    var savedSession: UserSession? {
        loadSession()
    }

    func restoreSavedSession(matchingEmail email: String? = nil) -> Bool {
        guard let savedSession = loadSession() else {
            return false
        }

        if let email,
           savedSession.email.caseInsensitiveCompare(email) != .orderedSame {
            return false
        }

        session = savedSession
        return true
    }

    func logout(clearSavedSession: Bool = true) {
        if !clearSavedSession {
            preserveSavedSessionOnNextClear = true
        }

        session = nil

        if clearSavedSession {
            userDefaults.removeObject(forKey: sessionStorageKey)
        }
    }

    private func loadSession() -> UserSession? {
        guard let data = userDefaults.data(forKey: sessionStorageKey) else {
            return nil
        }

        do {
            return try JSONDecoder().decode(UserSession.self, from: data)
        } catch {
            userDefaults.removeObject(forKey: sessionStorageKey)
            return nil
        }
    }

    private func saveSession() {
        guard let session else {
            userDefaults.removeObject(forKey: sessionStorageKey)
            return
        }

        do {
            let data = try JSONEncoder().encode(session)
            userDefaults.set(data, forKey: sessionStorageKey)
        } catch {
            userDefaults.removeObject(forKey: sessionStorageKey)
        }
    }
}
