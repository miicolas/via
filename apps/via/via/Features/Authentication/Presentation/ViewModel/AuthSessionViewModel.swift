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
    @ObservationIgnored private var revalidatingGeneration: UInt64?
    @ObservationIgnored private var lifecycleTask: Task<Void, Never>?

    init(
        client: any AuthenticationClient,
        vault: any AuthSessionVault,
        account: AccountModel,
        unauthorizedEvents: AsyncStream<String> = AsyncStream { _ in },
        onAuthenticatedSessionEnded: @escaping @MainActor () async -> Void = {}
    ) {
        self.client = client
        self.vault = vault
        self.account = account
        self.onAuthenticatedSessionEnded = onAuthenticatedSessionEnded
        lifecycleTask = Task { [weak self] in
            for await rejectedBearerToken in unauthorizedEvents {
                guard let self else { return }
                await self.authenticatedRequestWasRejected(bearerToken: rejectedBearerToken)
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
            let initial = try await vault.snapshot()
            guard let storedSession = initial.session else {
                account.activateAnonymous()
                state = .signedOut
                await establishAnonymousSession()
                return
            }

            if storedSession.user.isAnonymous {
                anonymousSession = storedSession
                account.activateAnonymous()
                state = .signedOut
                await revalidateAnonymous(initial)
                return
            }

            account.activate(userID: storedSession.user.id)
            state = .authenticated(storedSession, .offline)
            // The server session is authoritative when restoring the app. The
            // local Apple credential state can be unavailable after a reinstall
            // or when running a development bundle, so it must not log out a
            // still-valid server session.
            await revalidateAuthenticatedSession(initial)
        } catch {
            // A malformed payload is the one recovery path that cannot carry a
            // snapshot identity. Clear it before starting a fresh anonymous
            // session; all normal mutations use a compare-and-clear below.
            try? await vault.clear()
            account.activateAnonymous()
            state = .signedOut
            errorMessage = "La session enregistrée est illisible. Reconnecte-toi avec Apple."
            await establishAnonymousSession()
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
            let baseline = try? await vault.snapshot()
            guard let baseline else {
                state = .signedOut
                errorMessage = "La connexion est momentanément indisponible. Réessaie."
                return
            }
            let bearerToken = baseline.session?.user.isAnonymous == true
                ? baseline.session?.bearerToken
                : nil
            do {
                let signedIn = try await client.signIn(
                    with: credentials,
                    existingBearerToken: bearerToken
                )
                guard !signedIn.user.isAnonymous else {
                    throw AuthenticationClientError.invalidResponse
                }
                guard let installed = try? await vault.install(
                    signedIn,
                    replacingGeneration: baseline.generation
                ) else { return }
                anonymousSession = nil
                account.activate(userID: signedIn.user.id)
                state = .authenticated(signedIn, .online)
                errorMessage = nil
                _ = installed
                account.synchronize()
            } catch {
                guard await isCurrent(baseline) else { return }
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
        guard revalidatingGeneration == nil,
              let snapshot = try? await vault.snapshot(),
              let storedSession = snapshot.session else { return }
        revalidatingGeneration = snapshot.generation
        defer {
            if revalidatingGeneration == snapshot.generation {
                revalidatingGeneration = nil
            }
        }
        if storedSession.user.isAnonymous {
            await revalidateAnonymous(snapshot)
        } else {
            await revalidateAuthenticatedSession(snapshot)
        }
    }

    func authenticatedRequestWasRejected(bearerToken: String) async {
        guard let snapshot = try? await vault.snapshot(),
              let currentSession = snapshot.session,
              currentSession.bearerToken == bearerToken else { return }
        if currentSession.user.isAnonymous {
            guard let cleared = try? await vault.clear(matching: snapshot) else { return }
            _ = cleared
            anonymousSession = nil
            account.activateAnonymous()
            await establishAnonymousSession()
        } else {
            await clearConfirmedSession(
                message: "Ta session n’est plus valide. Reconnecte-toi.",
                matching: snapshot
            )
        }
    }

    func appleCredentialWasRevoked() async {
        guard let snapshot = try? await vault.snapshot(),
              let currentSession = snapshot.session,
              !currentSession.user.isAnonymous else { return }
        await clearConfirmedSession(
            message: "Ton autorisation Apple a été révoquée. Reconnecte-toi.",
            matching: snapshot
        )
    }

    func signOut() async {
        guard let displayedSession = session,
              let snapshot = try? await vault.snapshot(),
              let storedSession = snapshot.session,
              !storedSession.user.isAnonymous,
              storedSession.user.id == displayedSession.user.id else { return }
        await onAuthenticatedSessionEnded()
        try? await client.signOut(bearerToken: storedSession.bearerToken)
        guard let cleared = try? await vault.clear(matchingGeneration: snapshot.generation) else { return }
        _ = cleared
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
        guard let snapshot = try? await vault.snapshot() else { return }
        if let storedSession = snapshot.session {
            if storedSession.user.isAnonymous {
                try? await client.deleteAnonymousUser(bearerToken: storedSession.bearerToken)
            } else {
                await onAuthenticatedSessionEnded()
                try? await client.signOut(bearerToken: storedSession.bearerToken)
            }
        }
        let cleared: AuthSessionSnapshot?
        if snapshot.session == nil {
            cleared = try? await vault.clear(matching: snapshot)
        } else {
            cleared = try? await vault.clear(matchingGeneration: snapshot.generation)
        }
        guard let cleared else { return }
        _ = cleared
        anonymousSession = nil
        account.eraseDeviceData()
        state = .signedOut
        errorMessage = nil
        await establishAnonymousSession()
    }

    func completeAccountDeletion(_ outcome: AppleDeletionOutcome) async {
        guard let snapshot = try? await vault.snapshot(),
              let currentSession = snapshot.session,
              !currentSession.user.isAnonymous else { return }
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
                await onAuthenticatedSessionEnded()
                guard let cleared = try? await vault.clear(matchingGeneration: snapshot.generation) else { return }
                _ = cleared
                anonymousSession = nil
                account.activateAnonymous()
                state = .signedOut
                errorMessage = nil
                await establishAnonymousSession()
            } catch {
                guard await isCurrent(snapshot) else { return }
                errorMessage = "La révocation Apple a échoué. Le compte a été conservé; tu peux réessayer."
            }
        }
    }

    private func establishAnonymousSession() async {
        guard let baseline = try? await vault.snapshot(),
              baseline.session == nil,
              session == nil,
              anonymousSession == nil else { return }
        do {
            let anonymous = try await client.signInAnonymously()
            guard anonymous.user.isAnonymous else { return }
            guard let installed = try? await vault.install(
                anonymous,
                replacingGeneration: baseline.generation
            ) else { return }
            _ = installed
            anonymousSession = anonymous
            account.activateAnonymous()
        } catch is CancellationError {
        } catch {
            // The local anonymous workspace remains fully usable offline.
        }
    }

    private func revalidateAuthenticatedSession(_ snapshot: AuthSessionSnapshot) async {
        guard let storedSession = snapshot.session, !storedSession.user.isAnonymous else { return }
        do {
            let refreshed = try await client.validate(storedSession)
            guard let accepted = try? await vault.refresh(refreshed, matching: snapshot) else { return }
            _ = accepted
            state = .authenticated(refreshed, .online)
            errorMessage = nil
            account.synchronize()
        } catch AuthenticationClientError.unauthorized {
            await clearConfirmedSession(
                message: "Ta session a expiré. Reconnecte-toi avec Apple.",
                matching: snapshot
            )
        } catch is CancellationError {
        } catch {
            guard await isCurrent(snapshot) else { return }
            state = .authenticated(storedSession, .offline)
        }
    }

    private func revalidateAnonymous(_ snapshot: AuthSessionSnapshot) async {
        guard let storedSession = snapshot.session, storedSession.user.isAnonymous else { return }
        do {
            let refreshed = try await client.validate(storedSession)
            guard let accepted = try? await vault.refresh(refreshed, matching: snapshot) else { return }
            _ = accepted
            anonymousSession = refreshed
        } catch AuthenticationClientError.unauthorized {
            guard let cleared = try? await vault.clear(matching: snapshot) else { return }
            _ = cleared
            anonymousSession = nil
            await establishAnonymousSession()
        } catch is CancellationError {
        } catch {
            // The cached anonymous token can continue to serve as an offline
            // transport credential until the next successful validation.
        }
    }

    private func clearConfirmedSession(
        message: String,
        matching snapshot: AuthSessionSnapshot
    ) async {
        await onAuthenticatedSessionEnded()
        guard let cleared = try? await vault.clear(matching: snapshot) else { return }
        _ = cleared
        anonymousSession = nil
        account.activateAnonymous()
        state = .signedOut
        errorMessage = message
        await establishAnonymousSession()
    }

    private func isCurrent(_ snapshot: AuthSessionSnapshot) async -> Bool {
        guard let current = try? await vault.snapshot() else { return false }
        return current == snapshot
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
