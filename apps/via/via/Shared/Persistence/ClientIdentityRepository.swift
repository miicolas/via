import Foundation
import Security

protocol ClientIdentityRepository: Sendable {
    func clientID() throws -> String
}

final class KeychainClientIdentityRepository: ClientIdentityRepository {
    private let service = "dev.via.app.identity.v1"
    private let account = "anonymous-client-id"

    func clientID() throws -> String {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var item: CFTypeRef?
        let readStatus = SecItemCopyMatching(query as CFDictionary, &item)
        if readStatus == errSecSuccess,
           let data = item as? Data,
           let value = String(data: data, encoding: .utf8) {
            return value
        }
        guard readStatus == errSecItemNotFound else { throw ViaError.unavailable }

        let value = UUID().uuidString.lowercased()
        query[kSecValueData as String] = Data(value.utf8)
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        query.removeValue(forKey: kSecReturnData as String)
        query.removeValue(forKey: kSecMatchLimit as String)

        guard SecItemAdd(query as CFDictionary, nil) == errSecSuccess else {
            throw ViaError.unavailable
        }
        return value
    }
}

