import AuthenticationServices
import UIKit

@MainActor
final class AppleDeletionAuthorizer: NSObject {
    private var completion: ((AppleDeletionOutcome) -> Void)?
    private var nonce: String?

    func authorize(completion: @escaping (AppleDeletionOutcome) -> Void) {
        do {
            let nonce = try AppleSignInNonce.generate()
            self.nonce = nonce
            self.completion = completion

            let request = ASAuthorizationAppleIDProvider().createRequest()
            request.nonce = AppleSignInNonce.sha256(nonce)
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        } catch {
            completion(.failed)
        }
    }

    private func finish(_ outcome: AppleDeletionOutcome) {
        let completion = completion
        self.completion = nil
        nonce = nil
        completion?(outcome)
    }
}

extension AppleDeletionAuthorizer: ASAuthorizationControllerDelegate {
    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let identityTokenData = credential.identityToken,
              let authorizationCodeData = credential.authorizationCode,
              let identityToken = String(data: identityTokenData, encoding: .utf8),
              let authorizationCode = String(data: authorizationCodeData, encoding: .utf8),
              let nonce else {
            finish(.failed)
            return
        }
        finish(.authorized(AccountDeletionProof(
            identityToken: identityToken,
            authorizationCode: authorizationCode,
            nonce: nonce
        )))
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: any Error
    ) {
        if let authorizationError = error as? ASAuthorizationError,
           authorizationError.code == .canceled {
            finish(.cancelled)
        } else {
            finish(.failed)
        }
    }
}

extension AppleDeletionAuthorizer: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        let windowScenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        if let keyWindow = windowScenes.flatMap(\.windows).first(where: \.isKeyWindow) {
            return keyWindow
        }
        guard let windowScene = windowScenes.first else {
            preconditionFailure("La confirmation Apple requiert une scène iOS active.")
        }
        return ASPresentationAnchor(windowScene: windowScene)
    }
}
