import SwiftUI
import GoogleSignIn
import AuthenticationServices

struct LoginView: View {

    let onLoginSuccess: (UserSession) -> Void

    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack {

            Spacer()

            Image("new_logo")
                .resizable()
                .scaledToFit()
                .frame(width: 140, height: 140)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.white, lineWidth: 2))

            Text("Welcome to The Manager Life")
                .font(.title2)
                .foregroundColor(.blue)
                .multilineTextAlignment(.center)
                .padding()

            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .padding(.horizontal)
            }

            Button(action: {
                signInWithGoogle()
            }) {
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
                    .cornerRadius(24)
                }
            }
            .buttonStyle(.plain)
            .disabled(isLoading)

//            Spacer()
            
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
            
            Spacer()

            Text("TML v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "")")
                .font(.footnote)
                .padding(.bottom, 12)
        }
        .padding()
    }
}

// MARK: - Google Sign In
extension LoginView {

    func signInWithGoogle() {

        guard let rootVC = UIApplication.shared
            .connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first?
            .windows
            .first?
            .rootViewController else {
                errorMessage = "Unable to access root controller."
                return
        }

        isLoading = true
        errorMessage = nil

        GIDSignIn.sharedInstance.signIn(withPresenting: rootVC) { result, error in

            if let error = error {
                isLoading = false
                errorMessage = error.localizedDescription
                return
            }

            guard let idToken = result?.user.idToken?.tokenString else {
                isLoading = false
                errorMessage = "Failed to retrieve ID token."
                return
            }

            sendTokenToBackend(idToken: idToken)
        }
    }
    
    func handleAppleLogin(result: Result<ASAuthorization, Error>) {

        switch result {

        case .success(let authorization):

            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let identityToken = credential.identityToken,
                  let tokenString = String(data: identityToken, encoding: .utf8)
            else {
                errorMessage = "Unable to retrieve Apple identity token."
                return
            }

            sendAppleTokenToBackend(idToken: tokenString)

        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }
    
    func sendAppleTokenToBackend(idToken: String) {

        guard let url = URL(string:
            "https://app-javabackend-5e1ae1d5056c.herokuapp.com/users/mobile/apple"
        ) else {
            errorMessage = "Invalid backend URL."
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ["idToken": idToken]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { data, response, error in

            DispatchQueue.main.async {
                isLoading = false
            }

            if let error = error {
                DispatchQueue.main.async {
                    errorMessage = error.localizedDescription
                }
                return
            }

            // ✅ DEFINE httpResponse HERE
            guard let data = data,
                  let httpResponse = response as? HTTPURLResponse else {

                DispatchQueue.main.async {
                    errorMessage = "No response from backend."
                }
                return
            }

            // ✅ DEBUG PRINTS HERE
            print("Status Code:", httpResponse.statusCode)
            print("Response:", String(data: data, encoding: .utf8) ?? "No body")

            guard httpResponse.statusCode == 200 else {

                DispatchQueue.main.async {
                    errorMessage =
                        "Apple login failed (\(httpResponse.statusCode))"
                }

                return
            }

            do {

                let json =
                    try JSONSerialization.jsonObject(with: data)
                    as? [String: Any]

                guard let token = json?["token"] as? String,
                      let user = json?["user"] as? [String: Any] else {

                    DispatchQueue.main.async {
                        errorMessage = "Invalid backend response."
                    }

                    return
                }

                let session = UserSession(
                    jwt: token,
                    userId: user["id"] as? String ?? "",
                    userName: user["name"] as? String ?? "",
                    email: user["email"] as? String ?? "",
                    userImage: user["image"] as? String,
                    appRole: user["appRole"] as? String ?? "MEMBER",
                    accessRole: user["accessRole"] as? String ?? "USER"
                )

                DispatchQueue.main.async {
                    onLoginSuccess(session)
                }

            } catch {

                DispatchQueue.main.async {
                    errorMessage =
                        "Failed to parse backend response."
                }
            }

        }.resume()
    }

    func sendTokenToBackend(idToken: String) {

        guard let url = URL(string: "https://app-javabackend-5e1ae1d5056c.herokuapp.com/users/mobile") else {
            errorMessage = "Invalid backend URL."
            isLoading = false
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ["idToken": idToken]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { data, response, error in

            DispatchQueue.main.async {
                isLoading = false
            }

            if let error = error {
                DispatchQueue.main.async {
                    errorMessage = error.localizedDescription
                }
                return
            }

//            guard let data = data,
//                  let httpResponse = response as? HTTPURLResponse,
//                  httpResponse.statusCode == 200 else {
//                DispatchQueue.main.async {
//                    errorMessage = "Backend authentication failed."
//                }
//                return
//            }
            
            guard let data = data,
                  let httpResponse = response as? HTTPURLResponse else {
                DispatchQueue.main.async {
                    errorMessage = "No response from backend."
                }
                return
            }

            print("Status Code:", httpResponse.statusCode)
            print("Response:", String(data: data, encoding: .utf8) ?? "No body")

            guard httpResponse.statusCode == 200 else {
                DispatchQueue.main.async {
                    errorMessage = "Backend auth failed (\(httpResponse.statusCode))"
                }
                return
            }

            do {
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

                guard let token = json?["token"] as? String,
                      let user = json?["user"] as? [String: Any] else {
                    DispatchQueue.main.async {
                        errorMessage = "Invalid backend response."
                    }
                    return
                }

                let session = UserSession(
                    jwt: token,
                    userId: user["id"] as? String ?? "",
                    userName: user["name"] as? String ?? "",
                    email: user["email"] as? String ?? "",
                    userImage: user["image"] as? String,
                    appRole: user["appRole"] as? String ?? "MEMBER",
                    accessRole: user["accessRole"] as? String ?? "USER"
                )

                DispatchQueue.main.async {
                    onLoginSuccess(session)
                }

            } catch {
                DispatchQueue.main.async {
                    errorMessage = "Failed to parse backend response."
                }
            }

        }.resume()
    }
}
