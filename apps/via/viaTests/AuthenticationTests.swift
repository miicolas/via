import XCTest
@testable import Via

final class AuthenticationTests: XCTestCase {
    func testNonceHashMatchesAppleRequestFormat() {
        XCTAssertEqual(
            AppleSignInNonce.sha256("abc"),
            "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
        )
    }

    func testGeneratedNoncesAreRandomAndThirtyTwoCharacters() throws {
        let first = try AppleSignInNonce.generate()
        let second = try AppleSignInNonce.generate()

        XCTAssertEqual(first.count, 32)
        XCTAssertEqual(second.count, 32)
        XCTAssertNotEqual(first, second)
    }

    func testAvatarUsesTwoInitialsAndFallsBackWhenNameIsMissing() {
        XCTAssertEqual(user(name: "Camille Martin").initials, "CM")
        XCTAssertEqual(user(name: "Prince").initials, "P")
        XCTAssertNil(user(name: "").initials)
    }

    @MainActor
    func testRestoreWithoutStoredSessionSignsOutAndLeavesAccountInactive() async {
        let fixture = makeFixture()

        await fixture.viewModel.restore()

        XCTAssertEqual(fixture.viewModel.state, .signedOut)
        XCTAssertEqual(fixture.account.state, .inactive)
    }

    @MainActor
    func testRestoreKeepsAStoredSessionOfflineWhenValidationCannotReachTheServer() async {
        let stored = session(token: "stored")
        let fixture = makeFixture(
            storedSession: stored,
            validationError: .transport
        )

        await fixture.viewModel.restore()

        XCTAssertEqual(fixture.viewModel.state, .authenticated(stored, .offline))
        assertAccountIsActive(fixture.account)
    }

    @MainActor
    func testRestoreReplacesAStoredSessionAfterOnlineValidation() async throws {
        let stored = session(token: "stored")
        let refreshed = session(token: "refreshed")
        let fixture = makeFixture(
            storedSession: stored,
            validatedSession: refreshed
        )

        await fixture.viewModel.restore()

        XCTAssertEqual(fixture.viewModel.state, .authenticated(refreshed, .online))
        let vaultedSession = try await fixture.vault.load()
        XCTAssertEqual(vaultedSession, refreshed)
        assertAccountIsActive(fixture.account)
    }

    @MainActor
    func testCancelledAndInvalidAppleSignInStaySignedOut() async {
        let fixture = makeFixture()

        await fixture.viewModel.completeSignIn(.cancelled)
        XCTAssertEqual(fixture.viewModel.state, .signedOut)
        XCTAssertNil(fixture.viewModel.errorMessage)

        await fixture.viewModel.completeSignIn(.failed)
        XCTAssertEqual(fixture.viewModel.state, .signedOut)
        XCTAssertNotNil(fixture.viewModel.errorMessage)
        XCTAssertEqual(fixture.account.state, .inactive)
    }

    @MainActor
    func testRevokedAppleCredentialClearsSessionAndAccount() async throws {
        let fixture = makeFixture(
            storedSession: session(),
            credentialStatus: .revoked
        )

        await fixture.viewModel.restore()

        XCTAssertEqual(fixture.viewModel.state, .signedOut)
        XCTAssertEqual(fixture.account.state, .inactive)
        let vaultedSession = try await fixture.vault.load()
        XCTAssertNil(vaultedSession)
    }

    @MainActor
    func testUnauthorizedLifecycleEventClearsSessionAndAccount() async {
        let fixture = makeFixture(storedSession: session())
        await fixture.viewModel.restore()

        fixture.lifecycleContinuation.yield(.authenticatedRequestRejected)
        await waitUntil { fixture.viewModel.state == .signedOut }

        XCTAssertEqual(fixture.account.state, .inactive)
        XCTAssertNotNil(fixture.viewModel.errorMessage)
    }

    @MainActor
    func testSignOutClearsVaultAndDeactivatesAccount() async throws {
        let fixture = makeFixture(storedSession: session())
        await fixture.viewModel.restore()

        await fixture.viewModel.signOut()

        XCTAssertEqual(fixture.viewModel.state, .signedOut)
        XCTAssertEqual(fixture.account.state, .inactive)
        let vaultedSession = try await fixture.vault.load()
        XCTAssertNil(vaultedSession)
        let signOutCount = await fixture.client.signOutCount
        XCTAssertEqual(signOutCount, 1)
    }

    @MainActor
    func testSuccessfulDeletionErasesAccountBeforeClearingSession() async throws {
        let fixture = makeFixture(storedSession: session())
        await fixture.viewModel.restore()
        fixture.account.toggleFavorite(stationID: StationID(rawValue: "A"), name: "Nation")

        await fixture.viewModel.completeAccountDeletion(.authorized(deletionProof()))

        XCTAssertEqual(fixture.viewModel.state, .signedOut)
        XCTAssertEqual(fixture.account.state, .inactive)
        let vaultedSession = try await fixture.vault.load()
        XCTAssertNil(vaultedSession)
    }

    @MainActor
    func testFailedRemoteDeletionPreservesSessionAndLocalAccount() async throws {
        let stored = session()
        let fixture = makeFixture(
            storedSession: stored,
            deletionError: .transport
        )
        await fixture.viewModel.restore()
        fixture.account.toggleFavorite(stationID: StationID(rawValue: "A"), name: "Nation")

        await fixture.viewModel.completeAccountDeletion(.authorized(deletionProof()))

        XCTAssertEqual(fixture.viewModel.state, .authenticated(stored, .online))
        XCTAssertTrue(fixture.account.isFavorite(stationID: StationID(rawValue: "A")))
        let vaultedSession = try await fixture.vault.load()
        XCTAssertEqual(vaultedSession, stored)
        XCTAssertNotNil(fixture.viewModel.errorMessage)
    }

    @MainActor
    private func makeFixture(
        storedSession: StoredAuthSession? = nil,
        validatedSession: StoredAuthSession? = nil,
        validationError: AuthenticationClientError? = nil,
        credentialStatus: AppleCredentialStatus = .authorized,
        deletionError: ViaError? = nil
    ) -> AuthenticationFixture {
        let vault = InMemoryAuthSessionVault(session: storedSession)
        let client = AuthenticationClientStub(
            signInSession: validatedSession ?? storedSession ?? session(),
            validatedSession: validatedSession,
            validationError: validationError
        )
        let account = AccountModel(
            store: AccountLocalStore(
                defaults: UserDefaults(
                    suiteName: "dev.via.authentication-tests.\(UUID().uuidString)"
                )!
            ),
            remote: AuthenticationAccountRemote(deleteError: deletionError),
            synchronizationEnabled: false
        )
        let lifecycle = AsyncStream.makeStream(of: AuthLifecycleEvent.self)
        return AuthenticationFixture(
            viewModel: AuthSessionViewModel(
                client: client,
                vault: vault,
                credentialStatusChecker: InMemoryAppleCredentialStatusChecker(
                    value: credentialStatus
                ),
                account: account,
                lifecycleEvents: lifecycle.stream
            ),
            account: account,
            vault: vault,
            client: client,
            lifecycleContinuation: lifecycle.continuation
        )
    }

    @MainActor
    private func assertAccountIsActive(
        _ account: AccountModel,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard case .active = account.state else {
            XCTFail("Expected an active account", file: file, line: line)
            return
        }
    }

    @MainActor
    private func waitUntil(
        _ predicate: @escaping @MainActor () -> Bool,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        for _ in 0..<100 {
            if predicate() { return }
            try? await Task.sleep(for: .milliseconds(10))
        }
        XCTFail("Condition was not met", file: file, line: line)
    }

    private func session(token: String = "token") -> StoredAuthSession {
        StoredAuthSession(
            bearerToken: token,
            user: user(name: "Camille Martin"),
            expiresAt: .distantFuture,
            lastValidatedAt: .now
        )
    }

    private func deletionProof() -> AccountDeletionProof {
        AccountDeletionProof(
            identityToken: "identity",
            authorizationCode: "authorization",
            nonce: "nonce"
        )
    }

    private func user(name: String) -> AuthUser {
        AuthUser(
            id: "user",
            appleUserIdentifier: "apple",
            name: name,
            email: "user@example.com"
        )
    }
}

private struct AuthenticationFixture {
    let viewModel: AuthSessionViewModel
    let account: AccountModel
    let vault: InMemoryAuthSessionVault
    let client: AuthenticationClientStub
    let lifecycleContinuation: AsyncStream<AuthLifecycleEvent>.Continuation
}

private actor AuthenticationClientStub: AuthenticationClient {
    private let signInSession: StoredAuthSession
    private let validatedSession: StoredAuthSession?
    private let validationError: AuthenticationClientError?
    private(set) var signOutCount = 0

    init(
        signInSession: StoredAuthSession,
        validatedSession: StoredAuthSession?,
        validationError: AuthenticationClientError?
    ) {
        self.signInSession = signInSession
        self.validatedSession = validatedSession
        self.validationError = validationError
    }

    func signIn(with credentials: AppleSignInCredentials) -> StoredAuthSession {
        signInSession
    }

    func validate(_ session: StoredAuthSession) throws -> StoredAuthSession {
        if let validationError { throw validationError }
        return validatedSession ?? session
    }

    func signOut(bearerToken: String) {
        signOutCount += 1
    }
}

private actor AuthenticationAccountRemote: AccountRemote {
    private let deleteError: ViaError?

    init(deleteError: ViaError?) {
        self.deleteError = deleteError
    }

    func synchronize(_ operations: [AccountSyncOperation]) -> AccountSyncResult {
        AccountSyncResult(
            appliedOperationIDs: operations.map(\.operationID),
            favorites: [],
            recents: [],
            preferences: .empty,
            syncedAt: .now
        )
    }

    func delete(using proof: AccountDeletionProof) throws {
        if let deleteError { throw deleteError }
    }
}
