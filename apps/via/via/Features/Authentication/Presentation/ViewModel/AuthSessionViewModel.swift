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
    @ObservationIgnored private var didRestore = false
    @ObservationIgnored private var isRevalidating = false
    @ObservationIgnored private var lifecycleTask: Task<Void, Never>?

    init(
        client: any AuthenticationClient,
        vault: any AuthSessionVault,
        account: AccountModel,
        unauthorizedEvents: AsyncStream<Void> = AsyncStream { _ in }
    ) {
        self.client = client
        self.vault = vault
        self.account = account
        lifecycleTask = Task { [weak self] in
            for await _ in unauthorizedEvents {
                guard let self else { return }
                await self.authenticatedRequestWasRejected()
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
            // The server session is authoritative when restoring the app. The
            // local Apple credential state can be unavailable after a reinstall
            // or when running a development bundle, so it must not log out a
            // still-valid server session.
            await revalidate()
        } catch {
            state = .signedOut
            errorMessage = "La session enregistrée est illisible. Reconnecte-toi avec Apple."
        }
    }

    func completeSignIn(_ outcome: AppleSignInOutcome) async {
        switch outcome {
        case .cancelled:
            state = .signedOut
            errorMessage = nil

        case .failed:
            state = .signedOut
            errorMessage = "Apple n’a pas pu terminer la connexion."

        case .authorized(let credentials):
            state = .authenticating
            do {
                let session = try await client.signIn(with: credentials)
                try await vault.save(session)
                account.activate(userID: session.user.id)
                state = .authenticated(session, .online)
                errorMessage = nil
                account.synchronize()
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

    func revalidate() async {
        guard !isRevalidating, let displayedSession = session else { return }
        isRevalidating = true
        defer { isRevalidating = false }
        let storedSession = (try? await vault.load()) ?? displayedSession

        do {
            let refreshed = try await client.validate(storedSession)
            try await vault.save(refreshed)
            state = .authenticated(refreshed, .online)
            errorMessage = nil
            account.synchronize()
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

    func completeAccountDeletion(_ outcome: AppleDeletionOutcome) async {
        guard session != nil else { return }
        switch outcome {
        case .cancelled:
            errorMessage = nil

        case .failed:
            errorMessage = "Apple n’a pas pu confirmer la suppression."

        case .authorized(let proof):
            isDeletingAccount = true
            defer { isDeletingAccount = false }
            do {
                try await account.delete(using: proof)
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
