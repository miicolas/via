actor InMemoryAuthenticationClient: AuthenticationClient {
    private var session: StoredAuthSession

    init(session: StoredAuthSession) {
        self.session = session
    }

    func signIn(with credentials: AppleSignInCredentials) -> StoredAuthSession {
        session
    }

    func validate(_ session: StoredAuthSession) -> StoredAuthSession {
        self.session
    }

    func signOut(bearerToken: String) {}
}
