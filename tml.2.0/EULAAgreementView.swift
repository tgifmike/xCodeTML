import SwiftUI

struct EULAAgreementView: View {
    let isSubmitting: Bool
    let errorMessage: String?
    let onAccept: () -> Void
    let onDecline: () -> Void

    @State private var showDeclineMessage = false
    @State private var hasReachedAgreementBottom = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                GeometryReader { scrollArea in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 22) {
                            header
                            agreementText
                            bottomMarker
                        }
                        .padding(24)
                    }
                    .coordinateSpace(name: "EULAScroll")
                    .onPreferenceChange(EULABottomPreferenceKey.self) { bottomY in
                        hasReachedAgreementBottom = bottomY <= scrollArea.size.height + 8
                    }
                }

                Divider()

                VStack(spacing: 12) {
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }

                    if !hasReachedAgreementBottom {
                        Text("Scroll to the bottom to continue.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        guard hasReachedAgreementBottom else { return }
                        onAccept()
                    } label: {
                        if isSubmitting {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Agree and Continue")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(isSubmitting || !hasReachedAgreementBottom)

                    Button("Decline") {
                        showDeclineMessage = true
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                }
                .padding(20)
                .background(.background)
            }
            .navigationTitle("Terms of Use")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Agreement Required", isPresented: $showDeclineMessage) {
                Button("Back to Login", role: .destructive) {
                    onDecline()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("You must agree to the End User License Agreement before using this app.")
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image("new_tml_logo")
                .resizable()
                .scaledToFit()
                .frame(width: 96, height: 96)
                .accessibilityLabel("TML logo")

            Text("End User License Agreement")
                .font(.largeTitle.bold())

            Text("Please review and accept these terms before using the app.")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var agreementText: some View {
        VStack(alignment: .leading, spacing: 18) {
            section(
                title: "Authorized Use",
                body: "This app is intended for authorized users of the account, business, or organization that provides access to it. You are responsible for using the app only for permitted work activities."
            )

            section(
                title: "Account and PIN Security",
                body: "Keep your login credentials and PIN private. Do not share access with another person. Activity completed under your credentials may be associated with your user account."
            )

            section(
                title: "Operational Records",
                body: "Line checks, corrective actions, photos, device activity, and related entries may be stored and synced with the service. You agree to enter accurate information and correct mistakes when they are discovered."
            )

            section(
                title: "Offline Use",
                body: "Some features may work offline and sync later when a connection is available. Offline records remain subject to the same responsibilities as online records."
            )

            section(
                title: "Device Access",
                body: "The organization may enroll, revoke, or limit device access for security and operational reasons. If access is revoked, the app may require re-enrollment before PIN use is available again."
            )

            section(
                title: "No Warranty",
                body: "The app is provided as-is for operational support. Availability, syncing, printing, and network features may depend on device, printer, server, and internet conditions."
            )

            section(
                title: "Acceptance",
                body: "By tapping Agree and Continue, you confirm that you have read and accept this End User License Agreement."
            )
        }
    }

    private var bottomMarker: some View {
        Color.clear
            .frame(height: 1)
            .background {
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: EULABottomPreferenceKey.self,
                        value: proxy.frame(in: .named("EULAScroll")).maxY
                    )
                }
            }
    }

    private func section(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.headline)

            Text(body)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct EULABottomPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = .greatestFiniteMagnitude

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

#Preview {
    EULAAgreementView(
        isSubmitting: false,
        errorMessage: nil,
        onAccept: { },
        onDecline: { }
    )
}
