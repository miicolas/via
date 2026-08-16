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

enum AppleCredentialStatus: Sendable, Equatable {
    case authorized
    case revoked
    case notFound
    case transferred
    case unknown
}

protocol AppleCredentialStatusChecking: Sendable {
    func status(for appleUserIdentifier: String) async throws -> AppleCredentialStatus
}

enum AuthenticationClientError: Error, Sendable {
    case unauthorized
    case transport
    case server(statusCode: Int)
    case invalidResponse
}
