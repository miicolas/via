import AuthenticationServices
import Foundation

struct LiveAppleCredentialStatusChecker: AppleCredentialStatusChecking {
    func status(for appleUserIdentifier: String) async throws -> AppleCredentialStatus {
        try await withCheckedThrowingContinuation { continuation in
            ASAuthorizationAppleIDProvider().getCredentialState(
                forUserID: appleUserIdentifier
            ) { credentialState, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: Self.map(credentialState))
            }
        }
    }

    private static func map(
        _ state: ASAuthorizationAppleIDProvider.CredentialState
    ) -> AppleCredentialStatus {
        switch state {
        case .authorized:
            .authorized
        case .revoked:
            .revoked
        case .notFound:
            .notFound
        case .transferred:
            .transferred
        @unknown default:
            .unknown
        }
    }
}

struct InMemoryAppleCredentialStatusChecker: AppleCredentialStatusChecking {
    var value: AppleCredentialStatus = .authorized
    var error: AuthenticationClientError?

    func status(for appleUserIdentifier: String) async throws -> AppleCredentialStatus {
        if let error { throw error }
        return value
    }
}
