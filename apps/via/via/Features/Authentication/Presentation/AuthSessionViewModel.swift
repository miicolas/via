import AuthenticationServices
import Foundation
import Observation

@MainActor
@Observable
final class AuthSessionViewModel {
    private(set) var state: AuthSessionState = .loading
    private(set) var isDeletingAccount = false
    private(set) var errorMessage: String?

    @ObservationIgnored private let client: any AuthenticationClient
    @ObservationIgnored private let vault: any AuthSessionVault
    @ObservationIgnored private let account: AccountModel
    @ObservationIgnored private var signInNonce: String?
    @ObservationIgnored private var deletionNonce: String?
    @ObservationIgnored private var didRestore = false
    @ObservationIgnored private var isRevalidating = false
    @ObservationIgnored private var lifecycleTask: Task<Void, Never>?

    init(
        client: any AuthenticationClient,
        vault: any AuthSessionVault,
        account: AccountModel,
        lifecycleEvents: AsyncStream<AuthLifecycleEvent> = AsyncStream { _ in }
    ) {
        self.client = client
        self.vault = vault
        self.account = account
        lifecycleTask = Task { [weak self] in
            for await event in lifecycleEvents {
                guard let self else { return }
                await self.handle(event)
            }
        }
    }

    var session: StoredAuthSession? {
        guard case .authenticated(let session, _) = state else { return nil }
        return session
    }

    var connectivity: AuthConnectivity? {
        guard case .authenticated(_, let connectivity) = state else { return nil }
        return connectivity
    }

    func restore() async {
        guard !didRestore else { return }
        didRestore = true
        do {
            guard let session = try await vault.load() else {
                state = .signedOut
                return
            }
            account.activate(userID: session.user.id)
            state = .authenticated(session, .offline)
            await revalidate()
        } catch {
            state = .signedOut
            errorMessage = "La session enregistrée est illisible. Reconnecte-toi avec Apple."
        }
    }

    func configureSignInRequest(_ request: ASAuthorizationAppleIDRequest) {
        configure(
            request,
            storingNonceIn: \.signInNonce,
            failureMessage: "Impossible de préparer la connexion sécurisée."
        )
    }

    func completeSignIn(_ result: Result<ASAuthorization, any Error>) async {
        guard let nonce = signInNonce else {
            state = .signedOut
            errorMessage = "La tentative de connexion a expiré. Réessaie."
            return
        }
        signInNonce = nil

        switch result {
        case .failure(let error):
            state = .signedOut
            if let authorizationError = error as? ASAuthorizationError,
               authorizationError.code == .canceled {
                return
            }
            errorMessage = "Apple n’a pas pu terminer la connexion."

        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let identityTokenData = credential.identityToken,
                  let identityToken = String(data: identityTokenData, encoding: .utf8) else {
                state = .signedOut
                errorMessage = "Apple n’a pas fourni de jeton d’identité valide."
                return
            }
            state = .authenticating
            do {
                let credentials = AppleSignInCredentials(
                    appleUserIdentifier: credential.user,
                    identityToken: identityToken,
                    authorizationCode: credential.authorizationCode.flatMap {
                        String(data: $0, encoding: .utf8)
                    },
                    nonce: nonce,
                    givenName: credential.fullName?.givenName,
                    familyName: credential.fullName?.familyName,
                    email: credential.email
                )
                let session = try await client.signIn(with: credentials)
                try await vault.save(session)
                account.activate(userID: session.user.id)
                state = .authenticated(session, .online)
                errorMessage = nil
                account.resumeSynchronization()
            } catch {
                state = .signedOut
                errorMessage = message(for: error)
            }
        }
    }

    func sceneBecameActive() async {
        guard session != nil else { return }
        await revalidate()
    }

    func handle(_ event: AuthLifecycleEvent) async {
        switch event {
        case .sceneBecameActive:
            await sceneBecameActive()
        case .authenticatedRequestRejected:
            await authenticatedRequestWasRejected()
        case .appleCredentialRevoked:
            await appleCredentialWasRevoked()
        }
    }

    func revalidate() async {
        guard !isRevalidating, let displayedSession = session else { return }
        isRevalidating = true
        defer { isRevalidating = false }
        let storedSession = (try? await vault.load()) ?? displayedSession

        do {
            let credentialState = try await appleCredentialState(
                for: storedSession.user.appleUserIdentifier
            )
            switch credentialState {
            case .revoked, .notFound:
                await clearConfirmedSession(
                    message: "Ton autorisation Apple a été révoquée. Reconnecte-toi."
                )
                return
            case .authorized, .transferred:
                break
            @unknown default:
                break
            }
        } catch {
            // A failed Apple status lookup is not proof of revocation. The API
            // validation below decides whether this is online or offline use.
        }

        do {
            let refreshed = try await client.validate(storedSession)
            try await vault.save(refreshed)
            state = .authenticated(refreshed, .online)
            errorMessage = nil
            account.resumeSynchronization()
        } catch AuthenticationClientError.unauthorized {
            await clearConfirmedSession(message: "Ta session a expiré. Reconnecte-toi avec Apple.")
        } catch is CancellationError {
        } catch {
            state = .authenticated(storedSession, .offline)
        }
    }

    func authenticatedRequestWasRejected() async {
        guard session != nil else { return }
        await clearConfirmedSession(message: "Ta session n’est plus valide. Reconnecte-toi.")
    }

    func appleCredentialWasRevoked() async {
        guard session != nil else { return }
        await clearConfirmedSession(
            message: "Ton autorisation Apple a été révoquée. Reconnecte-toi."
        )
    }

    func signOut() async {
        guard let displayedSession = session else { return }
        let storedSession = (try? await vault.load()) ?? displayedSession
        try? await client.signOut(bearerToken: storedSession.bearerToken)
        try? await vault.clear()
        account.deactivate()
        state = .signedOut
        errorMessage = nil
    }

    func configureDeletionRequest(_ request: ASAuthorizationAppleIDRequest) {
        configure(
            request,
            storingNonceIn: \.deletionNonce,
            failureMessage: "Impossible de préparer la confirmation Apple."
        )
    }

    private func configure(
        _ request: ASAuthorizationAppleIDRequest,
        storingNonceIn noncePath: ReferenceWritableKeyPath<AuthSessionViewModel, String?>,
        failureMessage: String
    ) {
        do {
            let nonce = try AppleSignInNonce.generate()
            self[keyPath: noncePath] = nonce
            request.requestedScopes = [.fullName, .email]
            request.nonce = AppleSignInNonce.sha256(nonce)
            errorMessage = nil
        } catch {
            self[keyPath: noncePath] = nil
            errorMessage = failureMessage
        }
    }

    func completeAccountDeletion(_ result: Result<ASAuthorization, any Error>) async {
        guard let storedSession = session, let nonce = deletionNonce else { return }
        deletionNonce = nil

        switch result {
        case .failure(let error):
            if let authorizationError = error as? ASAuthorizationError,
               authorizationError.code == .canceled {
                return
            }
            errorMessage = "Apple n’a pas pu confirmer la suppression."

        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let identityTokenData = credential.identityToken,
                  let authorizationCodeData = credential.authorizationCode,
                  let identityToken = String(data: identityTokenData, encoding: .utf8),
                  let authorizationCode = String(data: authorizationCodeData, encoding: .utf8) else {
                errorMessage = "Apple n’a pas fourni les éléments de révocation nécessaires."
                return
            }

            isDeletingAccount = true
            defer { isDeletingAccount = false }
            do {
                try await account.delete(using: AccountDeletionProof(
                    identityToken: identityToken,
                    authorizationCode: authorizationCode,
                    nonce: nonce
                ))
                try await vault.clear()
                state = .signedOut
                errorMessage = nil
            } catch {
                errorMessage = "La révocation Apple a échoué. Le compte a été conservé; tu peux réessayer."
            }
        }
    }

    private func clearConfirmedSession(message: String) async {
        try? await vault.clear()
        account.deactivate()
        state = .signedOut
        errorMessage = message
    }

    private func appleCredentialState(
        for userID: String
    ) async throws -> ASAuthorizationAppleIDProvider.CredentialState {
        try await withCheckedThrowingContinuation { continuation in
            ASAuthorizationAppleIDProvider().getCredentialState(forUserID: userID) { state, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: state)
                }
            }
        }
    }

    private func message(for error: any Error) -> String {
        switch error {
        case AuthenticationClientError.transport:
            "Une connexion Internet est nécessaire pour la première connexion."
        case AuthenticationClientError.unauthorized:
            "Apple n’a pas pu valider cette connexion."
        default:
            "La connexion est momentanément indisponible. Réessaie."
        }
    }
}

extension AuthSessionViewModel {
    static var preview: AuthSessionViewModel { AppDependencies.preview.authSession }
}
