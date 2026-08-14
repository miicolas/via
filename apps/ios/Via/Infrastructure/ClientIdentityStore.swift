import Foundation
import Security

struct NativeClientMetadata: Sendable {
    let platform: String
    let version: String
    let build: String

    init(platform: String = "ios-native", version: String, build: String) {
        self.platform = platform
        self.version = version
        self.build = build
    }

    static var current: NativeClientMetadata {
        let info = Bundle.main.infoDictionary ?? [:]
        return NativeClientMetadata(
            version: info["CFBundleShortVersionString"] as? String ?? "0",
            build: info["CFBundleVersion"] as? String ?? "0"
        )
    }
}

struct ClientIdentityStore: Sendable {
    private let service = "dev.via.app"
    private let account = "via.anonymous-client-id"

    var identifier: String {
        if let existing = read() { return existing }
        let created = UUID().uuidString.lowercased()
        save(created)
        return created
    }

    private func read() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8)
        else { return nil }
        return value
    }

    private func save(_ value: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: Data(value.utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        SecItemAdd(query as CFDictionary, nil)
    }
}
