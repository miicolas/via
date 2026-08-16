import AuthenticationServices
import Foundation

@MainActor
final class AppleAuthorizationAdapter {
    private var signInNonce: String?
    private var deletionNonce: String?

    func configureSignInRequest(_ request: ASAuthorizationAppleIDRequest) {
        signInNonce = configure(request)
    }

    func signInOutcome(
        from result: Result<ASAuthorization, any Error>
    ) -> AppleSignInOutcome {
        defer { signInNonce = nil }
        switch result {
        case .failure(let error):
            return isCancellation(error) ? .cancelled : .failed
        case .success(let authorization):
            guard
                let nonce = signInNonce,
                let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                let identityToken = string(from: credential.identityToken)
            else { return .failed }

            return .authorized(AppleSignInCredentials(
                appleUserIdentifier: credential.user,
                identityToken: identityToken,
                authorizationCode: string(from: credential.authorizationCode),
                nonce: nonce,
                givenName: credential.fullName?.givenName,
                familyName: credential.fullName?.familyName,
                email: credential.email
            ))
        }
    }

    func configureDeletionRequest(_ request: ASAuthorizationAppleIDRequest) {
        deletionNonce = configure(request)
    }

    func deletionOutcome(
        from result: Result<ASAuthorization, any Error>
    ) -> AppleDeletionOutcome {
        defer { deletionNonce = nil }
        switch result {
        case .failure(let error):
            return isCancellation(error) ? .cancelled : .failed
        case .success(let authorization):
            guard
                let nonce = deletionNonce,
                let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                let identityToken = string(from: credential.identityToken),
                let authorizationCode = string(from: credential.authorizationCode)
            else { return .failed }

            return .authorized(AccountDeletionProof(
                identityToken: identityToken,
                authorizationCode: authorizationCode,
                nonce: nonce
            ))
        }
    }

    private func configure(_ request: ASAuthorizationAppleIDRequest) -> String? {
        guard let nonce = try? AppleSignInNonce.generate() else { return nil }
        request.requestedScopes = [.fullName, .email]
        request.nonce = AppleSignInNonce.sha256(nonce)
        return nonce
    }

    private func string(from data: Data?) -> String? {
        data.flatMap { String(data: $0, encoding: .utf8) }
    }

    private func isCancellation(_ error: any Error) -> Bool {
        guard let authorizationError = error as? ASAuthorizationError else { return false }
        return authorizationError.code == .canceled
    }
}
