//
//  SettingsView.swift
//  tml.2.0
//
//  Created by mike on 4/21/26.
//

import SwiftUI

struct SettingsView: View {

    @EnvironmentObject var appSettings: AppSettings
    @EnvironmentObject var sessionManager: SessionManager
    
    var body: some View {

        ScrollView {

            VStack(spacing: 16) {

                completionModeCard

                Spacer()
            }
            .padding()
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private extension SettingsView {

    var completionModeCard: some View {

        VStack(alignment: .leading, spacing: 12) {

            Text("Line Check Completion Mode")
                .font(.headline)
            
            if !sessionManager.canEditCompletionMode {

                Label(
                    "Manager access required",
                    systemImage: "lock.fill"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            ForEach(LineCheckCompletionMode.allCases) { mode in

                Button {

                    if sessionManager.canEditCompletionMode {
                        appSettings.completionMode = mode
                    }

                } label: {

                    HStack {

                        VStack(alignment: .leading, spacing: 4) {

                            Text(mode.title)
                                .font(.subheadline.weight(.semibold))

                            Text(mode.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if appSettings.completionMode == mode {

                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.blue)
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color(.systemBackground))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.black.opacity(0.05))
                    )
                }
                .buttonStyle(.plain)
                .disabled(!sessionManager.canEditCompletionMode)
                .opacity(sessionManager.canEditCompletionMode ? 1 : 0.45)
            }
        }
    }
}
