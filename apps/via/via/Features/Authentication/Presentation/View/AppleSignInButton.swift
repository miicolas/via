import AuthenticationServices
import SwiftUI

struct AppleSignInButton: View {
    let authSessionViewModel: AuthSessionViewModel
    /// Apple's own button, in the colour its ground calls for: black on the
    /// light sheet in Réglages, white on the first run's black stage — where a
    /// black button would simply disappear.
    var style: SignInWithAppleButton.Style = .black

    @State private var rawNonce: String?
    @State private var authorizerError: String?

    var body: some View {
        VStack(spacing: 10) {
            switch authSessionViewModel.state {
            case .loading:
                ProgressView("Restauration de la session…")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)

            case .authenticating:
                ProgressView("Connexion avec Apple…")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)

            case .signedOut, .authenticated:
                SignInWithAppleButton(
                    .signIn,
                    onRequest: configureAppleRequest,
                    onCompletion: completeAppleRequest
                )
                .signInWithAppleButtonStyle(style)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .clipShape(Capsule())
                .accessibilityLabel("Se connecter avec Apple")
            }

            if let message = authSessionViewModel.errorMessage ?? authorizerError {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func configureAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        do {
            let nonce = try AppleSignInNonce.generate()
            rawNonce = nonce
            authorizerError = nil
            request.requestedScopes = [.fullName, .email]
            request.nonce = AppleSignInNonce.sha256(nonce)
        } catch {
            rawNonce = nil
            authorizerError = "Apple n’a pas pu préparer la connexion. Réessaie."
        }
    }

    private func completeAppleRequest(_ result: Result<ASAuthorization, any Error>) {
        let outcome = makeOutcome(from: result, rawNonce: rawNonce)
        rawNonce = nil
        Task {
            await authSessionViewModel.completeSignIn(outcome)
        }
    }

    private func makeOutcome(
        from result: Result<ASAuthorization, any Error>,
        rawNonce: String?
    ) -> AppleSignInOutcome {
        switch result {
        case .failure(let error):
            if let authorizationError = error as? ASAuthorizationError,
               authorizationError.code == .canceled {
                return .cancelled
            }
            return .failed

        case .success(let authorization):
            guard
                let rawNonce,
                let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                let identityTokenData = credential.identityToken,
                let identityToken = String(data: identityTokenData, encoding: .utf8)
            else {
                return .failed
            }

            return .authorized(AppleSignInCredentials(
                appleUserIdentifier: credential.user,
                identityToken: identityToken,
                authorizationCode: credential.authorizationCode.flatMap {
                    String(data: $0, encoding: .utf8)
                },
                nonce: rawNonce,
                givenName: credential.fullName?.givenName,
                familyName: credential.fullName?.familyName,
                email: credential.email
            ))
        }
    }
}
