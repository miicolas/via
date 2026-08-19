import Foundation

struct AuthUser: Codable, Sendable, Hashable, Identifiable {
    let id: String
    let appleUserIdentifier: String
    let name: String
    let email: String
    let isAnonymous: Bool

    init(
        id: String,
        appleUserIdentifier: String,
        name: String,
        email: String,
        isAnonymous: Bool = false
    ) {
        self.id = id
        self.appleUserIdentifier = appleUserIdentifier
        self.name = name
        self.email = email
        self.isAnonymous = isAnonymous
    }

    var displayName: String {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedName.isEmpty ? email : trimmedName
    }

    var initials: String? {
        let words = name.split(whereSeparator: { $0.isWhitespace })
        let value = words.prefix(2).compactMap(\.first).map(String.init).joined().uppercased()
        return value.isEmpty ? nil : value
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case appleUserIdentifier
        case name
        case email
        case isAnonymous
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        appleUserIdentifier = try container.decode(String.self, forKey: .appleUserIdentifier)
        name = try container.decode(String.self, forKey: .name)
        email = try container.decode(String.self, forKey: .email)
        isAnonymous = try container.decodeIfPresent(Bool.self, forKey: .isAnonymous) ?? false
    }
}

struct StoredAuthSession: Codable, Sendable, Hashable {
    var bearerToken: String
    var user: AuthUser
    var expiresAt: Date
    var lastValidatedAt: Date
}

enum AuthConnectivity: Sendable, Hashable {
    case online
    case offline
}

enum AuthSessionState: Sendable, Hashable {
    case loading
    case signedOut
    case authenticating
    case authenticated(StoredAuthSession, AuthConnectivity)
}

struct AppleSignInCredentials: Sendable, Equatable {
    let appleUserIdentifier: String
    let identityToken: String
    let authorizationCode: String?
    let nonce: String
    let givenName: String?
    let familyName: String?
    let email: String?
}

enum AppleSignInOutcome: Sendable, Equatable {
    case authorized(AppleSignInCredentials)
    case cancelled
    case failed
}

enum AppleDeletionOutcome: Sendable, Equatable {
    case authorized(AccountDeletionProof)
    case cancelled
    case failed
}

enum AuthenticationClientError: Error, Sendable {
    case unauthorized
    case transport
    case server(statusCode: Int)
    case invalidResponse
}
