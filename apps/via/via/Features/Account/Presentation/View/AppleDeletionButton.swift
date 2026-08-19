import AuthenticationServices
import SwiftUI

struct AppleDeletionButton: View {
    let onOutcome: (AppleDeletionOutcome) -> Void

    @State private var rawNonce: String?

    var body: some View {
        SignInWithAppleButton(
            .continue,
            onRequest: configure,
            onCompletion: complete
        )
        .signInWithAppleButtonStyle(.black)
        .frame(minHeight: 44)
        .clipShape(.rect(cornerRadius: 12))
        .accessibilityLabel("Confirmer avec Apple")
    }

    private func configure(_ request: ASAuthorizationAppleIDRequest) {
        do {
            let nonce = try AppleSignInNonce.generate()
            rawNonce = nonce
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
                  let authorizationCode = credential.authorizationCode,
                  let authorizationCodeString = String(data: authorizationCode, encoding: .utf8) else {
                onOutcome(.failed)
                return
            }
            onOutcome(.authorized(AccountDeletionProof(
                identityToken: identityTokenString,
                authorizationCode: authorizationCodeString,
                nonce: rawNonce
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
