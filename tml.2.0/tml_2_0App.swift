//
//  tml_2_0App.swift
//  tml.2.0
//
//  Created by mike on 2/24/26.
//

import SwiftUI
import GoogleSignIn

@main
struct tml_2_0App: App {

    @StateObject private var sessionManager = SessionManager()
    @StateObject private var appSettings = AppSettings()

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
            
            if let session = sessionManager.session {
                
                AccountPickerView()
                
            } else {
                
                LoginView(onLoginSuccess: { newSession in
                    sessionManager.session = newSession
                })
            }
            
        }
        .environmentObject(sessionManager)
        .environmentObject(appSettings)
    }
}
