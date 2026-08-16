import Foundation
import Security

protocol AuthSessionVault: Sendable {
    func load() async throws -> StoredAuthSession?
    func save(_ session: StoredAuthSession) async throws
    func updateBearer(_ bearerToken: String) async throws
    func clear() async throws
}

actor KeychainAuthSessionVault: AuthSessionVault {
    private let service = "dev.via.app.auth-session.v1"
    private let account = "better-auth"
    /// `load()` runs on every outgoing API request; the decoded session is
    /// cached so the Keychain is read once per launch, not once per request.
    /// `.some(nil)` records a known-empty vault; `nil` means not read yet.
    private var cachedSession: StoredAuthSession??

    func load() throws -> StoredAuthSession? {
        if let cachedSession { return cachedSession }

        var item: CFTypeRef?
        let status = SecItemCopyMatching([
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ] as CFDictionary, &item)

        if status == errSecItemNotFound {
            cachedSession = .some(nil)
            return nil
        }
        guard status == errSecSuccess, let data = item as? Data else {
            throw AuthenticationClientError.invalidResponse
        }
        let session = try JSONDecoder.via.decode(StoredAuthSession.self, from: data)
        cachedSession = session
        return session
    }

    func save(_ session: StoredAuthSession) throws {
        let data = try JSONEncoder.via.encode(session)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
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
        let status = SecItemDelete([
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ] as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw AuthenticationClientError.invalidResponse
        }
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
