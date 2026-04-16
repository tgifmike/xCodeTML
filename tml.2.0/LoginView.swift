import SwiftUI
import GoogleSignIn
import AuthenticationServices

struct LoginView: View {

    @Environment(\.colorScheme) private var colorScheme
    
    let onLoginSuccess: (UserSession) -> Void

    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showErrorAlert = false
    @State private var attemptedEmail: String?
    @State private var logoTapCount = 0
    @State private var showDemoButton = false

    var body: some View {

        VStack {

            Spacer()

            Image("new_logo")
                .resizable()
                .scaledToFit()
                .frame(width: 140, height: 140)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.white, lineWidth: 2))
                .onTapGesture {
                        logoTapCount += 1
                        
                        if logoTapCount >= 5 {
                            showDemoButton = true
                            logoTapCount = 0
                        }
                    }

            Text("Welcome to The Manager Life")
                .font(.title2)
                .foregroundColor(.blue)
                .multilineTextAlignment(.center)
                .padding()

            Button(action: signInWithGoogle) {

                if isLoading {
                    ProgressView()
                        .tint(.white)
                        .frame(height: 56)
                        .frame(maxWidth: 250)

                } else {

                    HStack {

                        Image("ic_google_logo")
                            .resizable()
                            .frame(width: 24, height: 24)
                            .cornerRadius(26)

                        Text("Sign in with Google")
                            .font(.headline)
                    }
                    .frame(height: 56)
                    .frame(maxWidth: 250)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(26)
                }
            }
            .buttonStyle(.plain)
            .disabled(isLoading)


            SignInWithAppleButton(
                .signIn,
                onRequest: { request in
                    request.requestedScopes = [.fullName, .email]
                },
                onCompletion: handleAppleLogin
            )
            .signInWithAppleButtonStyle(.black)
            .frame(height: 56)
            .frame(maxWidth: 250)
            .cornerRadius(24)
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(
                        colorScheme == .dark
                        ? Color.white.opacity(0.4)
                        : Color.black.opacity(0.2),
                        lineWidth: 1
                    )
            )
            
            if allowDemoMode {
                Button("Demo Mode") {
                    loginDemoUser()
                }
            }

            Spacer()

            Text("TML v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "")")
                .font(.footnote)
                .padding(.bottom, 12)
        }
        .padding()
        .alert("Login Failed",
               isPresented: $showErrorAlert) {

            Button("OK", role: .cancel) {}

        } message: {

            Text(errorMessage ?? "Unknown error")
        }
    }
    
    private var allowDemoMode: Bool {

    #if DEBUG
        return true
    #else

        if ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] != nil {
            return true
        }

        guard let receiptURL = Bundle.main.appStoreReceiptURL else {
            return true
        }

        return receiptURL.lastPathComponent != "appStoreReceipt"

    #endif
    }
}

//////////////////////////////////////////////////////////////
// MARK: GOOGLE LOGIN
//////////////////////////////////////////////////////////////

extension LoginView {

    func signInWithGoogle() {

        guard let rootVC =
                UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first?
                .windows
                .first?
                .rootViewController else {

            showError("Unable to access root controller.")
            return
        }

        isLoading = true
        errorMessage = nil

        GIDSignIn.sharedInstance.signIn(withPresenting: rootVC) {

            result, error in

            if let error = error {

                finishLoading()
                showError(error.localizedDescription)
                return
            }

            guard let idToken =
                    result?.user.idToken?.tokenString else {

                finishLoading()
                showError("Failed to retrieve ID token.")
                return
            }

            attemptedEmail = result?.user.profile?.email

            sendTokenToBackend(
                idToken: idToken,
                provider: "google",
                endpoint: "https://app-javabackend-5e1ae1d5056c.herokuapp.com/users/oauth-login"
            )
        }
    }
}

//////////////////////////////////////////////////////////////
// MARK: APPLE LOGIN
//////////////////////////////////////////////////////////////

extension LoginView {

    func handleAppleLogin(result: Result<ASAuthorization, Error>) {

        switch result {

        case .success(let authorization):

            guard let credential =
                    authorization.credential
                    as? ASAuthorizationAppleIDCredential,

                  let identityToken =
                    credential.identityToken,

                  let tokenString =
                    String(data: identityToken,
                           encoding: .utf8) else {

                showError("Unable to retrieve Apple identity token.")
                return
            }

            isLoading = true

            sendTokenToBackend(
                idToken: tokenString,
                provider: "apple",
                endpoint: "https://app-javabackend-5e1ae1d5056c.herokuapp.com/users/oauth-login"
            )


        case .failure(let error):

            showError(error.localizedDescription)
        }
    }
}

//////////////////////////////////////////////////////////////
// MARK: BACKEND AUTH HANDLER (SHARED)
//////////////////////////////////////////////////////////////

extension LoginView {

    func sendTokenToBackend(
        idToken: String,
        provider: String,
        endpoint: String
    ) {

        guard let url = URL(string: endpoint) else {

            finishLoading()
            showError("Invalid backend URL.")
            return
        }

        var request = URLRequest(url: url)

        request.httpMethod = "POST"

        request.setValue(
            "application/json",
            forHTTPHeaderField: "Content-Type"
        )

        let body = [
            "idToken": idToken,
            "provider": provider
        ]

        request.httpBody =
            try? JSONSerialization.data(
                withJSONObject: body
            )

        URLSession.shared.dataTask(with: request) {

            data, response, error in

            DispatchQueue.main.async {

                finishLoading()
            }

            if let error = error {

                DispatchQueue.main.async {

                    showError(error.localizedDescription)
                }

                return
            }

            guard let data = data,
                  let httpResponse =
                    response as? HTTPURLResponse else {

                DispatchQueue.main.async {

                    showError("No response from backend.")
                }

                return
            }

            print("Status:", httpResponse.statusCode)

            switch httpResponse.statusCode {

            case 200:

                handleSuccessfulLogin(data: data)

            case 403:

                DispatchQueue.main.async {

                    showError(
                        "Your account exists but has not been activated yet. Contact your administrator."
                    )
                }

            case 401, 404:

                DispatchQueue.main.async {

                    showError(
                        attemptedEmail != nil
                        ? "The account \(attemptedEmail!) is not authorized."
                        : "This account is not authorized."
                    )
                }

            default:

                DispatchQueue.main.async {

                    showError(
                        "Login failed. Please try again."
                    )
                }
            }

        }.resume()
    }
}

//////////////////////////////////////////////////////////////
// MARK: SUCCESS PARSER
//////////////////////////////////////////////////////////////

extension LoginView {

    func handleSuccessfulLogin(data: Data) {

        print("RAW LOGIN RESPONSE:", String(data: data, encoding: .utf8) ?? "nil")
        
        do {

            let json =
                try JSONSerialization.jsonObject(with: data)
                as? [String: Any]

            guard let token =
                    json?["token"] as? String,

                  let userId =
                    json?["userId"] as? String,

                  let email =
                    json?["email"] as? String else {

                DispatchQueue.main.async {
                    showError("Invalid backend response.")
                }
                return
            }

            let session = UserSession(
                jwt: token,
                userId: userId,
                userName: json?["name"] as? String ?? "",
                email: email,
                userImage: json?["userImage"] as? String,
                appRole: json?["appRole"] as? String ?? "MEMBER",
                accessRole: json?["accessRole"] as? String ?? "USER"
            )

            DispatchQueue.main.async {
                onLoginSuccess(session)
            }

        } catch {

            DispatchQueue.main.async {
                showError("Failed to parse backend response.")
            }
        }
    }
}

//////////////////////////////////////////////////////////////
// MARK: HELPERS
//////////////////////////////////////////////////////////////

extension LoginView {

    func showError(_ message: String) {

        errorMessage = message
        showErrorAlert = true
    }

    func finishLoading() {

        isLoading = false
    }
}

//////////////////////////////////////////////////////////////
// MARK: login demo user
//////////////////////////////////////////////////////////////

extension LoginView {
    func loginDemoUser() {

        guard allowDemoMode else { return }

        guard let url =
            URL(string:
                "https://app-javabackend-5e1ae1d5056c.herokuapp.com/users/demo-login")
        else { return }

        var request = URLRequest(url: url)

        request.httpMethod = "POST"

        URLSession.shared.dataTask(with: request) {

            data, _, _ in

            guard let data else { return }

            DispatchQueue.main.async {

                handleSuccessfulLogin(data: data)
            }

        }.resume()
    }}
