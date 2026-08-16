import Foundation

struct AuthUser: Codable, Sendable, Hashable, Identifiable {
    let id: String
    let appleUserIdentifier: String
    let name: String
    let email: String

    var displayName: String {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedName.isEmpty ? email : trimmedName
    }

    var initials: String? {
        let words = name.split(whereSeparator: { $0.isWhitespace })
        let value = words.prefix(2).compactMap(\.first).map(String.init).joined().uppercased()
        return value.isEmpty ? nil : value
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

enum AuthLifecycleEvent: Sendable, Equatable {
    case sceneBecameActive
    case authenticatedRequestRejected
    case appleCredentialRevoked
}

struct AppleSignInCredentials: Sendable {
    let appleUserIdentifier: String
    let identityToken: String
    let authorizationCode: String?
    let nonce: String
    let givenName: String?
    let familyName: String?
    let email: String?
}

enum AuthenticationClientError: Error, Sendable {
    case unauthorized
    case transport
    case server(statusCode: Int)
    case invalidResponse
}
