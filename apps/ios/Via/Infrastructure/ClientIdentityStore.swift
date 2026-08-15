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

struct ClientIdentityHeaders: Sendable {
    private let clientIdentifier: String
    private let metadata: NativeClientMetadata

    init(clientIdentifier: String, metadata: NativeClientMetadata) {
        self.clientIdentifier = clientIdentifier
        self.metadata = metadata
    }

    func applying(to request: URLRequest) -> URLRequest {
        var request = request
        request.setValue(clientIdentifier, forHTTPHeaderField: "x-via-client-id")
        request.setValue(metadata.platform, forHTTPHeaderField: "x-via-client-platform")
        request.setValue(metadata.version, forHTTPHeaderField: "x-via-client-version")
        request.setValue(metadata.build, forHTTPHeaderField: "x-via-client-build")
        return request
    }
}

protocol ClientIdentityKeychain: Sendable {
    func read(
        service: String,
        account: String,
        accountUsesDataAttribute: Bool
    ) -> String?
    func save(value: String, service: String, account: String)
}

struct SystemClientIdentityKeychain: ClientIdentityKeychain {
    func read(
        service: String,
        account: String,
        accountUsesDataAttribute: Bool
    ) -> String? {
        let encodedAccount = Data(account.utf8)
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: accountUsesDataAttribute ? encodedAccount : account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        if accountUsesDataAttribute {
            query[kSecAttrGeneric as String] = encodedAccount
        }

        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8),
              !value.isEmpty
        else { return nil }
        return value
    }

    func save(value: String, service: String, account: String) {
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

struct ClientIdentityStore: Sendable {
    private let keychain: any ClientIdentityKeychain
    private let nativeService = "dev.via.app"
    private let expoServices = ["app:no-auth", "app:auth", "app"]
    private let account = "via.anonymous-client-id"

    init(keychain: any ClientIdentityKeychain = SystemClientIdentityKeychain()) {
        self.keychain = keychain
    }

    var identifier: String {
        if let existing = keychain.read(
            service: nativeService,
            account: account,
            accountUsesDataAttribute: false
        ) {
            return existing
        }

        for service in expoServices {
            if let legacy = keychain.read(
                service: service,
                account: account,
                accountUsesDataAttribute: true
            ) {
                keychain.save(value: legacy, service: nativeService, account: account)
                return legacy
            }
        }

        let created = UUID().uuidString.lowercased()
        keychain.save(value: created, service: nativeService, account: account)
        return created
    }
}
