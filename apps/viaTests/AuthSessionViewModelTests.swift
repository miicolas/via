import Foundation
import XCTest
@testable import Via

@MainActor
final class AuthSessionViewModelTests: XCTestCase {
    func testValidationOfAAfterSignInBCannotReplaceTheNewIdentity() async {
        let sessionA = makeSession(id: "a", bearer: "a.token")
        let sessionB = makeSession(id: "b", bearer: "b.token")
        let vault = InMemoryAuthSessionVault(session: sessionA)
        let client = SuspendedAuthenticationClient(
            session: sessionA,
            signInResult: sessionB,
            validationResult: sessionA
        )
        let model = AuthSessionViewModel(
            client: client,
            vault: vault,
            account: makeAccount()
        )

        let restoreTask = Task { @MainActor in await model.restore() }
        await client.waitUntilValidationStarted()
        XCTAssertEqual(model.session?.user.id, "a")

        await model.completeSignIn(.authorized(makeCredentials(for: "b")))
        await client.resumeValidation(with: sessionA)
        await restoreTask.value

        let snapshot = await vault.snapshot()
        XCTAssertEqual(snapshot.session?.user.id, "b")
        XCTAssertEqual(model.session?.user.id, "b")
    }

    func testValidationOfAAfterSignOutCannotResurrectTheSession() async {
        let sessionA = makeSession(id: "a", bearer: "a.token")
        let anonymous = makeSession(id: "anonymous", bearer: "guest.token", anonymous: true)
        let vault = InMemoryAuthSessionVault(session: sessionA)
        let client = SuspendedAuthenticationClient(
            session: sessionA,
            anonymousSession: anonymous,
            validationResult: sessionA
        )
        let model = AuthSessionViewModel(
            client: client,
            vault: vault,
            account: makeAccount()
        )

        let restoreTask = Task { @MainActor in await model.restore() }
        await client.waitUntilValidationStarted()
        await model.signOut()
        await client.resumeValidation(with: sessionA)
        await restoreTask.value

        let snapshot = await vault.snapshot()
        XCTAssertTrue(snapshot.session?.user.isAnonymous == true)
        XCTAssertNil(model.session)
        XCTAssertEqual(model.state, .signedOut)
    }

    func testUnauthorizedBearerFromADoesNotClearInstalledB() async {
        let sessionA = makeSession(id: "a", bearer: "a.token")
        let sessionB = makeSession(id: "b", bearer: "b.token")
        let vault = InMemoryAuthSessionVault(session: sessionA)
        let baseline = await vault.snapshot()
        let installed = await vault.install(sessionB, replacingGeneration: baseline.generation)
        XCTAssertNotNil(installed)
        let model = AuthSessionViewModel(
            client: SuspendedAuthenticationClient(session: sessionB),
            vault: vault,
            account: makeAccount()
        )

        await model.authenticatedRequestWasRejected(bearerToken: "a.token")

        let snapshot = await vault.snapshot()
        XCTAssertEqual(snapshot.session?.user.id, "b")
        XCTAssertEqual(snapshot.session?.bearerToken, "b.token")
    }

    func testVaultRejectsStaleMutationsAndAllowsCurrentGenerationClear() async {
        let vault = InMemoryAuthSessionVault()
        let empty = await vault.snapshot()
        let sessionA = makeSession(id: "a", bearer: "a.token")
        let sessionB = makeSession(id: "b", bearer: "b.token")
        let installedA = await vault.install(sessionA, replacingGeneration: empty.generation)
        XCTAssertNotNil(installedA)

        let staleInstall = await vault.install(sessionB, replacingGeneration: empty.generation)
        XCTAssertNil(staleInstall)
        let currentA = await vault.snapshot()
        let staleRefresh = await vault.refresh(sessionA, matching: empty)
        XCTAssertNil(staleRefresh)

        let rotated = await vault.updateBearer("a.rotated", matching: currentA)
        XCTAssertNotNil(rotated)
        let staleBearer = await vault.updateBearer("stale.token", matching: currentA)
        XCTAssertNil(staleBearer)

        let cleared = await vault.clear(matchingGeneration: currentA.generation)
        XCTAssertNotNil(cleared)
        let final = await vault.snapshot()
        XCTAssertNil(final.session)
    }

    private func makeAccount() -> AccountModel {
        AccountModel(
            remote: InMemoryAccountRemote(),
            synchronizationEnabled: false
        )
    }
}

private actor SuspendedAuthenticationClient: AuthenticationClient {
    private var session: StoredAuthSession
    private let signInResult: StoredAuthSession?
    private let anonymousSession: StoredAuthSession?
    private let validationResult: StoredAuthSession?
    private var validationContinuation: CheckedContinuation<StoredAuthSession, Never>?
    private var validationStarted = false

    init(
        session: StoredAuthSession,
        signInResult: StoredAuthSession? = nil,
        anonymousSession: StoredAuthSession? = nil,
        validationResult: StoredAuthSession? = nil
    ) {
        self.session = session
        self.signInResult = signInResult
        self.anonymousSession = anonymousSession
        self.validationResult = validationResult
    }

    func signIn(
        with _: AppleSignInCredentials,
        existingBearerToken _: String?
    ) async throws -> StoredAuthSession {
        signInResult ?? session
    }

    func signInAnonymously() async throws -> StoredAuthSession {
        anonymousSession ?? session
    }

    func validate(_ captured: StoredAuthSession) async throws -> StoredAuthSession {
        if validationResult != nil {
            validationStarted = true
            return await withCheckedContinuation { continuation in
                validationContinuation = continuation
            }
        }
        return captured
    }

    func signOut(bearerToken _: String) async throws {}
    func deleteAnonymousUser(bearerToken _: String) async throws {}

    func waitUntilValidationStarted() async {
        while !validationStarted {
            await Task.yield()
        }
    }

    func resumeValidation(with value: StoredAuthSession) {
        validationContinuation?.resume(returning: value)
        validationContinuation = nil
    }
}

private func makeSession(
    id: String,
    bearer: String,
    anonymous: Bool = false
) -> StoredAuthSession {
    StoredAuthSession(
        bearerToken: bearer,
        user: AuthUser(
            id: id,
            appleUserIdentifier: anonymous ? "" : "apple-\(id)",
            name: anonymous ? "Invité" : "Utilisateur \(id)",
            email: "\(id)@example.com",
            isAnonymous: anonymous
        ),
        expiresAt: .distantFuture,
        lastValidatedAt: .now
    )
}

private func makeCredentials(for id: String) -> AppleSignInCredentials {
    AppleSignInCredentials(
        appleUserIdentifier: "apple-\(id)",
        identityToken: "identity-\(id)",
        authorizationCode: "code-\(id)",
        nonce: "nonce-\(id)",
        givenName: "Utilisateur",
        familyName: id,
        email: "\(id)@example.com"
    )
}
