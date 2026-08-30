import CryptoKit
import Foundation
import Security

struct MeetupDeviceIdentity: Sendable, Hashable {
    let keyId: String
    let publicKey: String
}

struct MeetupKeyEnvelope: Codable, Sendable, Hashable {
    let recipientKeyId: String
    let ciphertext: String
}

protocol MeetupCryptography: Sendable {
    func deviceIdentity() async throws -> MeetupDeviceIdentity
    func createGroupKey(meetupId: String, revision: Int) async throws -> String
    func hasGroupKey(meetupId: String, revision: Int) async -> Bool
    func groupKeyFragment(meetupId: String, revision: Int) async throws -> String
    func importGroupKey(_ value: String, meetupId: String, revision: Int) async throws
    func encrypt(
        location: MeetupPreciseLocation,
        meetupId: String,
        revision: Int
    ) async throws -> MeetupEncryptedPresence
    func decrypt(
        presence: MeetupEncryptedPresence,
        meetupId: String
    ) async throws -> MeetupPreciseLocation
    func envelope(
        meetupId: String,
        revision: Int,
        recipientKeyId: String,
        recipientPublicKey: String
    ) async throws -> MeetupKeyEnvelope
    func openEnvelope(
        _ envelope: MeetupKeyEnvelope,
        meetupId: String,
        revision: Int
    ) async throws
    func discardGroupKeys(meetupId: String) async
}

enum MeetupCryptoError: Error, Sendable {
    case invalidKey
    case keyUnavailable
    case keychain(OSStatus)
    case invalidCiphertext
}

actor MeetupCryptoVault: MeetupCryptography {
    private let service = "dev.via.app.meetup-crypto"
    private let defaults: UserDefaults
    private let encoder = JSONEncoder.via
    private let decoder = JSONDecoder.via

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func deviceIdentity() throws -> MeetupDeviceIdentity {
        let keyIdKey = "meetup.device-key-id"
        let keyId: String
        let privateKey: Curve25519.KeyAgreement.PrivateKey
        if let storedID = defaults.string(forKey: keyIdKey),
           let raw = try KeychainMeetupSecrets.read(service: service, account: "device-private"),
           let restored = try? Curve25519.KeyAgreement.PrivateKey(rawRepresentation: raw) {
            keyId = storedID
            privateKey = restored
        } else {
            keyId = UUID().uuidString.lowercased()
            privateKey = Curve25519.KeyAgreement.PrivateKey()
            try KeychainMeetupSecrets.write(
                privateKey.rawRepresentation,
                service: service,
                account: "device-private"
            )
            defaults.set(keyId, forKey: keyIdKey)
        }
        return MeetupDeviceIdentity(
            keyId: keyId,
            publicKey: privateKey.publicKey.rawRepresentation.base64URLEncodedString()
        )
    }

    func createGroupKey(meetupId: String, revision: Int) throws -> String {
        let key = SymmetricKey(size: .bits256)
        let raw = key.withUnsafeBytes { Data($0) }
        try storeGroupKey(raw, meetupId: meetupId, revision: revision)
        return raw.base64URLEncodedString()
    }

    func hasGroupKey(meetupId: String, revision: Int) -> Bool {
        (try? groupKey(meetupId: meetupId, revision: revision)) != nil
    }

    func groupKeyFragment(meetupId: String, revision: Int) throws -> String {
        try groupKey(meetupId: meetupId, revision: revision).base64URLEncodedString()
    }

    func importGroupKey(_ value: String, meetupId: String, revision: Int) throws {
        guard let raw = Data(base64URLEncoded: value), raw.count == 32 else {
            throw MeetupCryptoError.invalidKey
        }
        try storeGroupKey(raw, meetupId: meetupId, revision: revision)
    }

    func encrypt(
        location: MeetupPreciseLocation,
        meetupId: String,
        revision: Int
    ) throws -> MeetupEncryptedPresence {
        let rawKey = try groupKey(meetupId: meetupId, revision: revision)
        let payload = try encoder.encode(location)
        let authenticatedData = Data("\(meetupId):\(revision)".utf8)
        let combined = try MeetupPayloadCipher.seal(
            payload,
            key: rawKey,
            authenticatedData: authenticatedData
        )
        return MeetupEncryptedPresence(
            keyRevision: revision,
            ciphertext: combined.base64URLEncodedString(),
            sentAt: location.recordedAt
        )
    }

    func decrypt(
        presence: MeetupEncryptedPresence,
        meetupId: String
    ) throws -> MeetupPreciseLocation {
        let rawKey = try groupKey(meetupId: meetupId, revision: presence.keyRevision)
        guard let combined = Data(base64URLEncoded: presence.ciphertext)
        else { throw MeetupCryptoError.invalidCiphertext }
        let authenticatedData = Data("\(meetupId):\(presence.keyRevision)".utf8)
        let plaintext = try MeetupPayloadCipher.open(
            combined,
            key: rawKey,
            authenticatedData: authenticatedData
        )
        return try decoder.decode(MeetupPreciseLocation.self, from: plaintext)
    }

    func envelope(
        meetupId: String,
        revision: Int,
        recipientKeyId: String,
        recipientPublicKey: String
    ) throws -> MeetupKeyEnvelope {
        let identity = try devicePrivateKey()
        guard let publicData = Data(base64URLEncoded: recipientPublicKey),
              let recipient = try? Curve25519.KeyAgreement.PublicKey(rawRepresentation: publicData)
        else { throw MeetupCryptoError.invalidKey }
        let wrappingKey = try wrappingKey(
            privateKey: identity,
            publicKey: recipient,
            meetupId: meetupId,
            revision: revision
        )
        let groupKey = try groupKey(meetupId: meetupId, revision: revision)
        let box = try ChaChaPoly.seal(groupKey, using: wrappingKey)
        var payload = identity.publicKey.rawRepresentation
        payload.append(box.combined)
        return MeetupKeyEnvelope(
            recipientKeyId: recipientKeyId,
            ciphertext: payload.base64URLEncodedString()
        )
    }

    func openEnvelope(
        _ envelope: MeetupKeyEnvelope,
        meetupId: String,
        revision: Int
    ) throws {
        // Envelopes include the sender's ephemeral public key as the first 32
        // bytes, followed by the ChaChaPoly combined box.
        guard let data = Data(base64URLEncoded: envelope.ciphertext), data.count > 32 else {
            throw MeetupCryptoError.invalidCiphertext
        }
        let senderData = data.prefix(32)
        let sealedData = data.dropFirst(32)
        guard let sender = try? Curve25519.KeyAgreement.PublicKey(rawRepresentation: senderData),
              let box = try? ChaChaPoly.SealedBox(combined: sealedData)
        else { throw MeetupCryptoError.invalidCiphertext }
        let wrappingKey = try wrappingKey(
            privateKey: devicePrivateKey(),
            publicKey: sender,
            meetupId: meetupId,
            revision: revision
        )
        let raw = try ChaChaPoly.open(box, using: wrappingKey)
        guard raw.count == 32 else { throw MeetupCryptoError.invalidKey }
        try storeGroupKey(raw, meetupId: meetupId, revision: revision)
    }

    func discardGroupKeys(meetupId: String) {
        let prefix = "group:\(meetupId):"
        for account in (defaults.stringArray(forKey: "meetup.group-key-index") ?? [])
            where account.hasPrefix(prefix) {
            try? KeychainMeetupSecrets.delete(service: service, account: account)
        }
        let remaining = (defaults.stringArray(forKey: "meetup.group-key-index") ?? [])
            .filter { !$0.hasPrefix(prefix) }
        defaults.set(remaining, forKey: "meetup.group-key-index")
    }

    private func devicePrivateKey() throws -> Curve25519.KeyAgreement.PrivateKey {
        _ = try deviceIdentity()
        guard let raw = try KeychainMeetupSecrets.read(service: service, account: "device-private")
        else { throw MeetupCryptoError.keyUnavailable }
        return try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: raw)
    }

    private func wrappingKey(
        privateKey: Curve25519.KeyAgreement.PrivateKey,
        publicKey: Curve25519.KeyAgreement.PublicKey,
        meetupId: String,
        revision: Int
    ) throws -> SymmetricKey {
        let secret = try privateKey.sharedSecretFromKeyAgreement(with: publicKey)
        return secret.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: Data(meetupId.utf8),
            sharedInfo: Data("via-meetup-key-v\(revision)".utf8),
            outputByteCount: 32
        )
    }

    private func groupKey(meetupId: String, revision: Int) throws -> Data {
        guard let raw = try KeychainMeetupSecrets.read(
            service: service,
            account: groupAccount(meetupId: meetupId, revision: revision)
        ), raw.count == 32 else { throw MeetupCryptoError.keyUnavailable }
        return raw
    }

    private func storeGroupKey(_ raw: Data, meetupId: String, revision: Int) throws {
        guard raw.count == 32 else { throw MeetupCryptoError.invalidKey }
        let account = groupAccount(meetupId: meetupId, revision: revision)
        try KeychainMeetupSecrets.write(raw, service: service, account: account)
        var index = Set(defaults.stringArray(forKey: "meetup.group-key-index") ?? [])
        index.insert(account)
        defaults.set(index.sorted(), forKey: "meetup.group-key-index")
    }

    private func groupAccount(meetupId: String, revision: Int) -> String {
        "group:\(meetupId):\(revision)"
    }
}

enum MeetupPayloadCipher {
    static func seal(
        _ plaintext: Data,
        key: Data,
        authenticatedData: Data,
        nonce: Data? = nil
    ) throws -> Data {
        let symmetricKey = SymmetricKey(data: key)
        let box: ChaChaPoly.SealedBox
        if let nonce {
            box = try ChaChaPoly.seal(
                plaintext,
                using: symmetricKey,
                nonce: try ChaChaPoly.Nonce(data: nonce),
                authenticating: authenticatedData
            )
        } else {
            box = try ChaChaPoly.seal(
                plaintext,
                using: symmetricKey,
                authenticating: authenticatedData
            )
        }
        return box.combined
    }

    static func open(
        _ combined: Data,
        key: Data,
        authenticatedData: Data
    ) throws -> Data {
        let box = try ChaChaPoly.SealedBox(combined: combined)
        return try ChaChaPoly.open(
            box,
            using: SymmetricKey(data: key),
            authenticating: authenticatedData
        )
    }
}

enum KeychainMeetupSecrets {
    static func read(service: String, account: String) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else {
            throw MeetupCryptoError.keychain(status)
        }
        return data
    }

    static func write(_ data: Data, service: String, account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        let updated = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updated == errSecSuccess { return }
        guard updated == errSecItemNotFound else { throw MeetupCryptoError.keychain(updated) }
        var values = query
        values.merge(attributes) { _, new in new }
        let added = SecItemAdd(values as CFDictionary, nil)
        guard added == errSecSuccess else { throw MeetupCryptoError.keychain(added) }
    }

    static func delete(service: String, account: String) throws {
        let status = SecItemDelete([
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ] as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw MeetupCryptoError.keychain(status)
        }
    }
}

extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    init?(base64URLEncoded value: String) {
        var base64 = value
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        base64 += String(repeating: "=", count: (4 - base64.count % 4) % 4)
        self.init(base64Encoded: base64)
    }
}
