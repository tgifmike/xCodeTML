struct UserSession {
    let jwt: String
    let userId: String
    let userName: String
    let email: String
    let userImage: String?
    let appRole: String
    let accessRole: String
    let authProvider: AuthProvider
}
