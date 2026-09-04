struct UserSession: Codable {
    let jwt: String?
    let userId: String
    let userName: String
    let email: String
    let userImage: String?
    let appRole: String
    let accessRole: String
    let authProvider: AuthProvider
    let accountId: String?
    let locationId: String?

    init(
        jwt: String?,
        userId: String,
        userName: String,
        email: String,
        userImage: String?,
        appRole: String,
        accessRole: String,
        authProvider: AuthProvider,
        accountId: String? = nil,
        locationId: String? = nil
    ) {
        self.jwt = jwt
        self.userId = userId
        self.userName = userName
        self.email = email
        self.userImage = userImage
        self.appRole = appRole
        self.accessRole = accessRole
        self.authProvider = authProvider
        self.accountId = accountId
        self.locationId = locationId
    }
}
