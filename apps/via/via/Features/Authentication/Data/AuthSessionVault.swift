import Foundation
import CryptoKit
import Security

protocol AuthSessionVault: Sendable {
    func snapshot() async throws -> AuthSessionSnapshot
    func install(_ session: StoredAuthSession, replacingGeneration: UInt64) async throws -> AuthSessionSnapshot?
    func refresh(_ session: StoredAuthSession, matching snapshot: AuthSessionSnapshot) async throws -> AuthSessionSnapshot?
    func updateBearer(_ bearerToken: String, matching snapshot: AuthSessionSnapshot) async throws -> AuthSessionSnapshot?
    func clear(matching snapshot: AuthSessionSnapshot) async throws -> AuthSessionSnapshot?
    func clear(matchingGeneration generation: UInt64) async throws -> AuthSessionSnapshot?
    func clear() async throws
}

struct AuthSessionSnapshot: Sendable, Equatable {
    let session: StoredAuthSession?
    let generation: UInt64
    let revision: UInt64
}

actor KeychainAuthSessionVault: AuthSessionVault {
    private static let servicePrefix = "dev.via.app.auth-session.v2"
    private static let legacyService = "dev.via.app.auth-session.v1"
    private let service: String
    private let account = "better-auth"
    /// `load()` runs on every outgoing API request; the decoded session is
    /// cached so the Keychain is read once per launch, not once per request.
    /// `.some(nil)` records a known-empty vault; `nil` means not read yet.
    private var cachedSession: StoredAuthSession??
    private var generation: UInt64 = 0
    private var revision: UInt64 = 0

    init(apiBaseURL: URL) {
        service = Self.service(for: apiBaseURL)
    }

    static func service(for apiBaseURL: URL) -> String {
        let digest = SHA256.hash(data: Data(apiBaseURL.absoluteString.utf8))
        let suffix = digest.prefix(8).map { String(format: "%02x", $0) }.joined()
        return "\(servicePrefix).\(suffix)"
    }

    func snapshot() throws -> AuthSessionSnapshot {
        AuthSessionSnapshot(
            session: try loadSession(),
            generation: generation,
            revision: revision
        )
    }

    func install(
        _ session: StoredAuthSession,
        replacingGeneration expectedGeneration: UInt64
    ) throws -> AuthSessionSnapshot? {
        guard generation == expectedGeneration else { return nil }
        try writeSession(session)
        generation &+= 1
        revision &+= 1
        return AuthSessionSnapshot(session: session, generation: generation, revision: revision)
    }

    func refresh(
        _ session: StoredAuthSession,
        matching expected: AuthSessionSnapshot
    ) throws -> AuthSessionSnapshot? {
        guard try matches(expected),
              let current = try loadSession(),
              current.user.id == session.user.id,
              current.user.isAnonymous == session.user.isAnonymous else { return nil }
        try writeSession(session)
        revision &+= 1
        return AuthSessionSnapshot(session: session, generation: generation, revision: revision)
    }

    func updateBearer(
        _ bearerToken: String,
        matching expected: AuthSessionSnapshot
    ) throws -> AuthSessionSnapshot? {
        guard try matches(expected), var session = try loadSession() else { return nil }
        guard session.user.id == expected.session?.user.id,
              session.user.isAnonymous == expected.session?.user.isAnonymous else { return nil }
        guard session.bearerToken != bearerToken else {
            return AuthSessionSnapshot(session: session, generation: generation, revision: revision)
        }
        session.bearerToken = bearerToken
        try writeSession(session)
        revision &+= 1
        return AuthSessionSnapshot(session: session, generation: generation, revision: revision)
    }

    func clear(matching expected: AuthSessionSnapshot) throws -> AuthSessionSnapshot? {
        guard try matches(expected) else { return nil }
        try clear()
        generation &+= 1
        revision &+= 1
        return AuthSessionSnapshot(session: nil, generation: generation, revision: revision)
    }

    func clear(matchingGeneration expectedGeneration: UInt64) throws -> AuthSessionSnapshot? {
        guard generation == expectedGeneration, try loadSession() != nil else { return nil }
        try clear()
        generation &+= 1
        revision &+= 1
        return AuthSessionSnapshot(session: nil, generation: generation, revision: revision)
    }

    private func matches(_ expected: AuthSessionSnapshot) throws -> Bool {
        guard generation == expected.generation,
              revision == expected.revision else { return false }
        let current = try loadSession()
        return current == expected.session
    }

    private func loadSession() throws -> StoredAuthSession? {
        if let cachedSession { return cachedSession }

        if let session = try readSession(for: service) {
            cachedSession = session
            return session
        }

        // Migrate the pre-environment-scoped item once. This preserves an
        // existing login while preventing a local token from being reused in
        // production (or the reverse).
        if let legacySession = try readSession(for: Self.legacyService) {
            try writeSession(legacySession)
            try deleteSession(for: Self.legacyService)
            return legacySession
        }

        cachedSession = .some(nil)
        return nil
    }

    private func writeSession(_ session: StoredAuthSession) throws {
        let data = try JSONEncoder.via.encode(session)
        let query = keychainQuery(for: service)
        let updateStatus = SecItemUpdate(query as CFDictionary, [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ] as CFDictionary)
        if updateStatus == errSecSuccess {
            cachedSession = session
            return
        }
        guard updateStatus == errSecItemNotFound else {
            throw AuthenticationClientError.invalidResponse
        }

        var values = query
        values[kSecValueData as String] = data
        values[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        guard SecItemAdd(values as CFDictionary, nil) == errSecSuccess else {
            throw AuthenticationClientError.invalidResponse
        }
        cachedSession = session
    }

    func clear() throws {
        cachedSession = .some(nil)
        try deleteSession(for: service)
        try deleteSession(for: Self.legacyService)
    }

    private func readSession(for service: String) throws -> StoredAuthSession? {
        var item: CFTypeRef?
        let status = SecItemCopyMatching(
            keychainQuery(for: service, returningData: true) as CFDictionary,
            &item
        )

        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = item as? Data else {
            throw AuthenticationClientError.invalidResponse
        }
        return try JSONDecoder.via.decode(StoredAuthSession.self, from: data)
    }

    private func deleteSession(for service: String) throws {
        let status = SecItemDelete(keychainQuery(for: service) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw AuthenticationClientError.invalidResponse
        }
    }

    private func keychainQuery(
        for service: String,
        returningData: Bool = false
    ) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        if returningData {
            query[kSecReturnData as String] = true
            query[kSecMatchLimit as String] = kSecMatchLimitOne
        }
        return query
    }
}

actor InMemoryAuthSessionVault: AuthSessionVault {
    private var session: StoredAuthSession?
    private var generation: UInt64 = 0
    private var revision: UInt64 = 0

    init(session: StoredAuthSession? = nil) {
        self.session = session
    }

    func snapshot() -> AuthSessionSnapshot {
        AuthSessionSnapshot(session: session, generation: generation, revision: revision)
    }

    func install(_ session: StoredAuthSession, replacingGeneration expectedGeneration: UInt64) -> AuthSessionSnapshot? {
        guard generation == expectedGeneration else { return nil }
        self.session = session
        generation &+= 1
        revision &+= 1
        return snapshot()
    }

    func refresh(_ session: StoredAuthSession, matching expected: AuthSessionSnapshot) -> AuthSessionSnapshot? {
        guard matches(expected),
              let current = self.session,
              current.user.id == session.user.id,
              current.user.isAnonymous == session.user.isAnonymous else { return nil }
        self.session = session
        revision &+= 1
        return snapshot()
    }

    func updateBearer(_ bearerToken: String, matching expected: AuthSessionSnapshot) -> AuthSessionSnapshot? {
        guard matches(expected), var current = session,
              current.user.id == expected.session?.user.id,
              current.user.isAnonymous == expected.session?.user.isAnonymous else { return nil }
        guard current.bearerToken != bearerToken else { return snapshot() }
        current.bearerToken = bearerToken
        session = current
        revision &+= 1
        return snapshot()
    }

    func clear(matching expected: AuthSessionSnapshot) -> AuthSessionSnapshot? {
        guard matches(expected) else { return nil }
        session = nil
        generation &+= 1
        revision &+= 1
        return snapshot()
    }

    func clear(matchingGeneration expectedGeneration: UInt64) -> AuthSessionSnapshot? {
        guard generation == expectedGeneration, session != nil else { return nil }
        session = nil
        generation &+= 1
        revision &+= 1
        return snapshot()
    }

    private func matches(_ expected: AuthSessionSnapshot) -> Bool {
        generation == expected.generation && revision == expected.revision && session == expected.session
    }

    func clear() { session = nil }
}
