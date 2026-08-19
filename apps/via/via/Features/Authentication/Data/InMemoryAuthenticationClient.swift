actor InMemoryAuthenticationClient: AuthenticationClient {
    private var session: StoredAuthSession

    init(session: StoredAuthSession) {
        self.session = session
    }

    func signIn(
        with credentials: AppleSignInCredentials,
        existingBearerToken: String?
    ) -> StoredAuthSession {
        let displayName = [credentials.givenName, credentials.familyName]
            .compactMap { $0 }
            .joined(separator: " ")
        session.user = AuthUser(
            id: session.user.id,
            appleUserIdentifier: credentials.appleUserIdentifier,
            name: displayName.isEmpty ? session.user.name : displayName,
            email: credentials.email ?? session.user.email,
            isAnonymous: false
        )
        return session
    }

    func signInAnonymously() -> StoredAuthSession {
        var anonymous = session
        anonymous.user = AuthUser(
            id: session.user.id,
            appleUserIdentifier: "",
            name: "Invité",
            email: session.user.email,
            isAnonymous: true
        )
        session = anonymous
        return anonymous
    }

    func validate(_ session: StoredAuthSession) -> StoredAuthSession {
        self.session
    }

    func signOut(bearerToken: String) {}

    func deleteAnonymousUser(bearerToken: String) {}
}
