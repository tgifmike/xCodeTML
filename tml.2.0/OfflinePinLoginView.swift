import SwiftUI

struct OfflinePinLoginView: View {
    let onLoginSuccess: (UserSession) -> Void
    var showsCancelButton = true

    @Environment(\.dismiss) private var dismiss
    @StateObject private var pinStore = OfflinePinDeviceStore.shared
    @State private var pin = ""
    @State private var isVerifying = false
    @State private var errorMessage: String?
    @State private var failedPinAttempts = 0

    private let maxPinAttempts = 5

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                if pinStore.hasUsablePinLogin {
                    GeometryReader { proxy in
                        let isCompact = proxy.size.height < 680

                        ScrollView {
                            pinContent(isCompact: isCompact)
                                .frame(minHeight: proxy.size.height)
                        }
                        .scrollIndicators(.hidden)
                    }
                } else {
                    emptyState
                        .padding()
                }
            }
            .navigationTitle("Employee PIN")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if showsCancelButton {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                }
            }
            .onChange(of: pinStore.hasUsablePinLogin) { _, _ in
                pin = ""
                errorMessage = nil
                failedPinAttempts = 0
            }
        }
    }
}

private extension OfflinePinLoginView {
    func pinContent(isCompact: Bool) -> some View {
        VStack(spacing: isCompact ? 10 : 16) {
            Spacer(minLength: isCompact ? 2 : 10)

            header(isCompact: isCompact)

            pinDisplay(isCompact: isCompact)

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal)
            }

            numberPad(isCompact: isCompact)
                .frame(maxWidth: 340)

            verifyButton(isCompact: isCompact)
                .frame(maxWidth: 340)
                .padding(.bottom, isCompact ? 18 : 30)
        }
        .padding(.horizontal, 20)
        .padding(.top, isCompact ? 8 : 16)
        .padding(.bottom, isCompact ? 14 : 22)
        .frame(maxWidth: .infinity)
    }

    func header(isCompact: Bool) -> some View {
        VStack(spacing: isCompact ? 8 : 14) {
            Image("new_tml_logo")
                .resizable()
                .scaledToFit()
                .frame(width: isCompact ? 118 : 172, height: isCompact ? 58 : 86)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 5)

            VStack(spacing: 3) {
                Text("Unlock Line Checks")
                    .font(isCompact ? .headline.bold() : .title2.bold())

                Text("Enter your employee PIN for this iPad.")
                    .font(isCompact ? .caption : .subheadline)
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    var emptyState: some View {
        ContentUnavailableView(
            "PIN Login Not Ready",
            systemImage: "key.slash",
            description: Text("Sign in online as a manager once to enroll this iPad for employee PIN login.")
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    func pinDisplay(isCompact: Bool) -> some View {
        VStack(spacing: isCompact ? 4 : 10) {
            ZStack {
                if pin.isEmpty {
                    Text("Enter PIN")
                        .font(isCompact ? .subheadline.weight(.semibold) : .headline)
                        .foregroundStyle(.secondary)
                } else {
                    HStack(spacing: 12) {
                        ForEach(0..<pin.count, id: \.self) { _ in
                            Circle()
                                .fill(Color.primary)
                                .frame(width: 13, height: 13)
                        }
                    }
                    .transition(.opacity.combined(with: .scale))
                }
            }
            .frame(width: 180, height: isCompact ? 36 : 42)
            .background(Color(.systemBackground))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.black.opacity(0.08), lineWidth: 1)
            )

            if !isCompact {
                Text("4 or 6 digits")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .animation(.easeInOut(duration: 0.16), value: pin)
    }

    func numberPad(isCompact: Bool) -> some View {
        VStack(spacing: isCompact ? 7 : 10) {
            ForEach(numberPadRows, id: \.self) { row in
                HStack(spacing: isCompact ? 8 : 10) {
                    ForEach(row, id: \.self) { key in
                        pinPadButton(for: key, isCompact: isCompact)
                    }
                }
            }
        }
    }

    func verifyButton(isCompact: Bool) -> some View {
        Button {
            Task {
                await verifyPin()
            }
        } label: {
            HStack(spacing: 10) {
                if isVerifying {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "lock.open.fill")
                }

                Text(isVerifying ? "Verifying..." : "Unlock")
                    .font(.headline)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: isCompact ? 48 : 52)
            .background(canVerify ? Color.blue : Color.gray.opacity(0.55))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!canVerify || isVerifying)
    }

    var pinSlotCount: Int { 6 }

    var numberPadRows: [[String]] {
        [
            ["1", "2", "3"],
            ["4", "5", "6"],
            ["7", "8", "9"],
            ["clear", "0", "delete"]
        ]
    }

    var canVerify: Bool {
        pinStore.hasUsablePinLogin && (pin.count == 4 || pin.count == 6)
    }

    @ViewBuilder
    func pinPadButton(for key: String, isCompact: Bool) -> some View {
        Button {
            handlePinPadKey(key)
        } label: {
            Group {
                switch key {
                case "clear":
                    Image(systemName: "xmark")
                case "delete":
                    Image(systemName: "delete.left")
                default:
                    Text(key)
                }
            }
            .font(keyFont(for: key))
            .foregroundStyle(key == "clear" ? Color.secondary : Color.primary)
            .frame(maxWidth: .infinity)
            .frame(height: isCompact ? 52 : 62)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.black.opacity(0.06), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.04), radius: 5, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .disabled((key == "delete" || key == "clear") && pin.isEmpty)
        .opacity((key == "delete" || key == "clear") && pin.isEmpty ? 0.35 : 1)
    }

    func keyFont(for key: String) -> Font {
        switch key {
        case "clear", "delete":
            return .title3.weight(.semibold)
        default:
            return .system(size: 28, weight: .semibold)
        }
    }

    func handlePinPadKey(_ key: String) {
        errorMessage = nil

        switch key {
        case "clear":
            pin = ""
        case "delete":
            if !pin.isEmpty {
                pin.removeLast()
            }
        default:
            guard pin.count < pinSlotCount else { return }
            pin.append(key)
        }
    }

    func verifyPin() async {
        guard pinStore.hasUsablePinLogin else { return }

        isVerifying = true
        errorMessage = nil

        do {
            let result = try await pinStore.verifyPin(pin)
            let session = UserSession(
                jwt: result.actionToken,
                userId: result.userId,
                userName: result.userName,
                email: "pin-user@themanagerlife.local",
                userImage: nil,
                appRole: "MEMBER",
                accessRole: "USER",
                authProvider: .pin,
                accountId: result.accountId,
                locationId: result.locationId
            )
            failedPinAttempts = 0
            onLoginSuccess(session)
            dismiss()
        } catch {
            errorMessage = pinVerificationMessage(for: error)
        }

        pin = ""
        isVerifying = false
    }

    func pinVerificationMessage(for error: Error) -> String {
        switch error {
        case APIError.pinFailed(_, let nextLockoutUntil):
            return failedAttemptMessage(nextLockoutUntil: nextLockoutUntil)
        case OfflinePinDeviceStoreError.invalidPin:
            return failedAttemptMessage(nextLockoutUntil: nil)
        default:
            return error.localizedDescription
        }
    }

    func failedAttemptMessage(nextLockoutUntil: Date?) -> String {
        failedPinAttempts = min(failedPinAttempts + 1, maxPinAttempts)
        var message = "PIN verification failed try \(failedPinAttempts) of \(maxPinAttempts)."

        if let nextLockoutUntil {
            let formatter = DateFormatter()
            formatter.dateStyle = .none
            formatter.timeStyle = .short
            message += " Next wrong entry will lock this user until \(formatter.string(from: nextLockoutUntil))."
        }

        return message
    }
}
