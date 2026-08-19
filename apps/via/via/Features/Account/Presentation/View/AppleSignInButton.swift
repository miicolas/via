import AuthenticationServices
import SwiftUI

struct AppleSignInButton: View {
    let onOutcome: (AppleSignInOutcome) -> Void

    @State private var rawNonce: String?

    var body: some View {
        SignInWithAppleButton(
            .signIn,
            onRequest: configure,
            onCompletion: complete
        )
        .signInWithAppleButtonStyle(.black)
        .frame(minHeight: 44)
        .clipShape(.rect(cornerRadius: 12))
        .accessibilityLabel("Continuer avec Apple")
    }

    private func configure(_ request: ASAuthorizationAppleIDRequest) {
        do {
            let nonce = try AppleSignInNonce.generate()
            rawNonce = nonce
            request.requestedScopes = [.fullName, .email]
            request.nonce = AppleSignInNonce.sha256(nonce)
        } catch {
            onOutcome(.failed)
        }
    }

    private func complete(_ result: Result<ASAuthorization, any Error>) {
        guard let rawNonce else {
            onOutcome(.failed)
            return
        }

        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let identityToken = credential.identityToken,
                  let identityTokenString = String(data: identityToken, encoding: .utf8),
                  !credential.user.isEmpty else {
                onOutcome(.failed)
                return
            }

            let user = credential.user
            let authorizationCode = credential.authorizationCode
                .flatMap { String(data: $0, encoding: .utf8) }
            onOutcome(.authorized(AppleSignInCredentials(
                appleUserIdentifier: user,
                identityToken: identityTokenString,
                authorizationCode: authorizationCode,
                nonce: rawNonce,
                givenName: credential.fullName?.givenName,
                familyName: credential.fullName?.familyName,
                email: credential.email
            )))

        case .failure(let error):
            if (error as? ASAuthorizationError)?.code == .canceled {
                onOutcome(.cancelled)
            } else {
                onOutcome(.failed)
            }
        }
    }
}
