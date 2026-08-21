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
    @ObservationIgnored private let onAuthenticatedSessionEnded: @MainActor () async -> Void
    @ObservationIgnored private(set) var anonymousSession: StoredAuthSession?
    @ObservationIgnored private var didRestore = false
    @ObservationIgnored private var isRevalidating = false
    @ObservationIgnored private var lifecycleTask: Task<Void, Never>?

    init(
        client: any AuthenticationClient,
        vault: any AuthSessionVault,
        account: AccountModel,
        unauthorizedEvents: AsyncStream<Void> = AsyncStream { _ in },
        onAuthenticatedSessionEnded: @escaping @MainActor () async -> Void = {}
    ) {
        self.client = client
        self.vault = vault
        self.account = account
        self.onAuthenticatedSessionEnded = onAuthenticatedSessionEnded
        lifecycleTask = Task { [weak self] in
            for await _ in unauthorizedEvents {
                guard let self else { return }
                await self.authenticatedRequestWasRejected()
            }
        }
    }

    /// A non-anonymous Better Auth session. Anonymous sessions stay hidden
    /// from the account card: they only provide an authenticated transport and
    /// a safe link target for the next Apple sign-in.
    var session: StoredAuthSession? {
        guard case .authenticated(let session, _) = state,
              !session.user.isAnonymous else { return nil }
        return session
    }

    var connectivity: AuthConnectivity? {
        guard case .authenticated(_, let connectivity) = state else { return nil }
        return connectivity
    }

    var isSignedIn: Bool { session != nil }

    func restore() async {
        guard !didRestore else { return }
        didRestore = true
        do {
            guard let storedSession = try await vault.load() else {
                account.activateAnonymous()
                state = .signedOut
                await establishAnonymousSession()
                return
            }

            if storedSession.user.isAnonymous {
                anonymousSession = storedSession
                account.activateAnonymous()
                state = .signedOut
                await revalidateAnonymous()
                return
            }

            account.activate(userID: storedSession.user.id)
            state = .authenticated(storedSession, .offline)
            // The server session is authoritative when restoring the app. The
            // local Apple credential state can be unavailable after a reinstall
            // or when running a development bundle, so it must not log out a
            // still-valid server session.
            await revalidate()
        } catch {
            account.activateAnonymous()
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
                var bearerToken = anonymousSession?.bearerToken
                if bearerToken == nil,
                   let storedSession = try? await vault.load(),
                   storedSession.user.isAnonymous {
                    bearerToken = storedSession.bearerToken
                }
                let session = try await client.signIn(
                    with: credentials,
                    existingBearerToken: bearerToken
                )
                guard !session.user.isAnonymous else {
                    throw AuthenticationClientError.invalidResponse
                }
                try await vault.save(session)
                anonymousSession = nil
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
        guard session != nil || anonymousSession != nil else { return }
        await revalidate()
    }

    func revalidate() async {
        guard !isRevalidating else { return }
        if session != nil {
            await revalidateAuthenticatedSession()
        } else if anonymousSession != nil {
            await revalidateAnonymous()
        }
    }

    func authenticatedRequestWasRejected() async {
        if session != nil {
            await clearConfirmedSession(message: "Ta session n’est plus valide. Reconnecte-toi.")
        } else if anonymousSession != nil {
            try? await vault.clear()
            anonymousSession = nil
            account.activateAnonymous()
            await establishAnonymousSession()
        }
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
        await onAuthenticatedSessionEnded()
        try? await client.signOut(bearerToken: storedSession.bearerToken)
        try? await vault.clear()
        anonymousSession = nil
        account.activateAnonymous()
        state = .signedOut
        errorMessage = nil
        await establishAnonymousSession()
    }

    /// Removes the local workspace and all auth credentials. The remote user
    /// account remains intact; a fresh anonymous session may be established if
    /// the network is available.
    func eraseDeviceData() async {
        if let storedSession = try? await vault.load() {
            if storedSession.user.isAnonymous {
                try? await client.deleteAnonymousUser(bearerToken: storedSession.bearerToken)
            } else {
                await onAuthenticatedSessionEnded()
                try? await client.signOut(bearerToken: storedSession.bearerToken)
            }
        }
        try? await vault.clear()
        anonymousSession = nil
        account.eraseDeviceData()
        state = .signedOut
        errorMessage = nil
        await establishAnonymousSession()
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
                anonymousSession = nil
                account.activateAnonymous()
                state = .signedOut
                errorMessage = nil
                await establishAnonymousSession()
            } catch {
                errorMessage = "La révocation Apple a échoué. Le compte a été conservé; tu peux réessayer."
            }
        }
    }

    private func establishAnonymousSession() async {
        guard session == nil, anonymousSession == nil else { return }
        do {
            let session = try await client.signInAnonymously()
            try await vault.save(session)
            anonymousSession = session
            account.activateAnonymous()
        } catch is CancellationError {
        } catch {
            // The local anonymous workspace remains fully usable offline.
        }
    }

    private func revalidateAuthenticatedSession() async {
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

    private func revalidateAnonymous() async {
        guard !isRevalidating, let displayedSession = anonymousSession else { return }
        isRevalidating = true
        defer { isRevalidating = false }
        let storedSession = (try? await vault.load()) ?? displayedSession

        do {
            let refreshed = try await client.validate(storedSession)
            try await vault.save(refreshed)
            anonymousSession = refreshed
        } catch AuthenticationClientError.unauthorized {
            try? await vault.clear()
            anonymousSession = nil
            await establishAnonymousSession()
        } catch is CancellationError {
        } catch {
            // The cached anonymous token can continue to serve as an offline
            // transport credential until the next successful validation.
        }
    }

    private func clearConfirmedSession(message: String) async {
        try? await vault.clear()
        anonymousSession = nil
        account.activateAnonymous()
        state = .signedOut
        errorMessage = message
        await establishAnonymousSession()
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
