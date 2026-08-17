import Foundation
import CryptoKit
import Security

protocol AuthSessionVault: Sendable {
    func load() async throws -> StoredAuthSession?
    func save(_ session: StoredAuthSession) async throws
    func updateBearer(_ bearerToken: String) async throws
    func clear() async throws
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

    init(apiBaseURL: URL) {
        service = Self.service(for: apiBaseURL)
    }

    static func service(for apiBaseURL: URL) -> String {
        let digest = SHA256.hash(data: Data(apiBaseURL.absoluteString.utf8))
        let suffix = digest.prefix(8).map { String(format: "%02x", $0) }.joined()
        return "\(servicePrefix).\(suffix)"
    }

    func load() throws -> StoredAuthSession? {
        if let cachedSession { return cachedSession }

        if let session = try readSession(for: service) {
            cachedSession = session
            return session
        }

        // Migrate the pre-environment-scoped item once. This preserves an
        // existing login while preventing a local token from being reused in
        // production (or the reverse).
        if let legacySession = try readSession(for: Self.legacyService) {
            try save(legacySession)
            try deleteSession(for: Self.legacyService)
            return legacySession
        }

        cachedSession = .some(nil)
        return nil
    }

    func save(_ session: StoredAuthSession) throws {
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

    func updateBearer(_ bearerToken: String) throws {
        guard var session = try load(), session.bearerToken != bearerToken else { return }
        session.bearerToken = bearerToken
        try save(session)
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

    init(session: StoredAuthSession? = nil) {
        self.session = session
    }

    func load() -> StoredAuthSession? { session }
    func save(_ session: StoredAuthSession) { self.session = session }
    func updateBearer(_ bearerToken: String) {
        session?.bearerToken = bearerToken
    }
    func clear() { session = nil }
}
