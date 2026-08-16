import XCTest
@testable import Via

final class AccountModelTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "dev.via.account-model-tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    @MainActor
    func testActivationPreservesAndMigratesLegacyRecents() throws {
        let recent = RecentSearch(result: addressResult(id: "legacy"), savedAt: .distantPast)
        defaults.set(
            try JSONEncoder.via.encode([recent]),
            forKey: "via.recent-searches.v1"
        )
        let model = AccountModel(
            store: AccountLocalStore(defaults: defaults),
            remote: AccountRemoteStub(),
            synchronizationEnabled: false
        )

        model.activate(userID: "user")

        XCTAssertEqual(model.recentSearches, [recent])
        XCTAssertNil(defaults.data(forKey: "via.recent-searches.v1"))
    }

    @MainActor
    func testMutationsAreImmediatelyObservableThroughTheAccountInterface() {
        let date = Date(timeIntervalSince1970: 100)
        let model = AccountModel(
            store: AccountLocalStore(defaults: defaults),
            remote: AccountRemoteStub(),
            synchronizationEnabled: false,
            now: { date }
        )
        model.activate(userID: "user")

        model.toggleFavorite(stationID: StationID(rawValue: "A"), name: "Nation")
        model.recordRecentSearch(addressResult(id: "address"))
        model.setPreferred(.metro, enabled: true)

        XCTAssertTrue(model.isFavorite(stationID: StationID(rawValue: "A")))
        XCTAssertEqual(model.recentSearches.map(\.id), ["address"])
        XCTAssertEqual(model.transportPreferences.preferredModes, [.metro])
        XCTAssertEqual(model.syncState, .local)
    }

    @MainActor
    func testMutationDuringSynchronizationSurvivesCanonicalMerge() async throws {
        let remote = AccountRemoteStub()
        await remote.suspendNextSynchronization()
        let model = AccountModel(
            store: AccountLocalStore(defaults: defaults),
            remote: remote
        )
        model.activate(userID: "user")
        await waitUntil { model.syncState == .syncing }

        model.toggleFavorite(stationID: StationID(rawValue: "A"), name: "Nation")
        await remote.resumeSynchronization()
        await waitUntil {
            if case .synced = model.syncState { return true }
            return false
        }

        XCTAssertTrue(model.isFavorite(stationID: StationID(rawValue: "A")))
        let synchronizationCount = await remote.synchronizationCount
        XCTAssertEqual(synchronizationCount, 2)
    }

    @MainActor
    func testOfflineFailureRetainsDataAndManualRetrySynchronizes() async throws {
        let remote = AccountRemoteStub(error: .transport)
        let model = AccountModel(
            store: AccountLocalStore(defaults: defaults),
            remote: remote
        )
        model.activate(userID: "user")
        model.toggleFavorite(stationID: StationID(rawValue: "A"), name: "Nation")
        await waitUntil { model.syncState == .pendingOffline }
        XCTAssertTrue(model.isFavorite(stationID: StationID(rawValue: "A")))

        await remote.setError(nil)
        model.retrySynchronization()
        await waitUntil {
            if case .synced = model.syncState { return true }
            return false
        }

        XCTAssertTrue(model.isFavorite(stationID: StationID(rawValue: "A")))
    }

    @MainActor
    func testChangingUserCancelsAndIgnoresThePreviousSynchronization() async throws {
        let remote = AccountRemoteStub()
        await remote.suspendNextSynchronization()
        let model = AccountModel(
            store: AccountLocalStore(defaults: defaults),
            remote: remote
        )
        model.activate(userID: "first-user")
        await waitUntil { model.syncState == .syncing }
        model.toggleFavorite(stationID: StationID(rawValue: "FIRST"), name: "First")

        model.activate(userID: "second-user")
        model.toggleFavorite(stationID: StationID(rawValue: "SECOND"), name: "Second")
        await remote.resumeSynchronization()
        await waitUntil {
            if case .synced = model.syncState { return true }
            return false
        }

        XCTAssertFalse(model.isFavorite(stationID: StationID(rawValue: "FIRST")))
        XCTAssertTrue(model.isFavorite(stationID: StationID(rawValue: "SECOND")))
    }

    @MainActor
    func testDeletionFailurePreservesAccountAndSuccessErasesIt() async throws {
        let remote = AccountRemoteStub(deleteError: .transport)
        let model = AccountModel(
            store: AccountLocalStore(defaults: defaults),
            remote: remote,
            synchronizationEnabled: false
        )
        model.activate(userID: "user")
        model.toggleFavorite(stationID: StationID(rawValue: "A"), name: "Nation")
        let proof = AccountDeletionProof(
            identityToken: "identity",
            authorizationCode: "authorization",
            nonce: "nonce"
        )

        do {
            try await model.delete(using: proof)
            XCTFail("Deletion should fail")
        } catch {
            XCTAssertTrue(model.isFavorite(stationID: StationID(rawValue: "A")))
        }

        await remote.setDeleteError(nil)
        try await model.delete(using: proof)
        XCTAssertEqual(model.state, .inactive)
        XCTAssertNil(defaults.data(forKey: "via.account-data.v1.user"))
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

    private func addressResult(id: String) -> SearchResult {
        .address(AddressSearchResult(
            id: id,
            name: "Adresse \(id)",
            context: "Paris",
            coordinate: GeoCoordinate(latitude: 48.85, longitude: 2.35),
            distanceMeters: nil
        ))
    }
}

private actor AccountRemoteStub: AccountRemote {
    private var snapshot = AccountLocalSnapshot()
    private var error: ViaError?
    private var deleteError: ViaError?
    private var shouldSuspendNext = false
    private var suspendedContinuation: CheckedContinuation<Void, Never>?
    private(set) var synchronizationCount = 0

    init(error: ViaError? = nil, deleteError: ViaError? = nil) {
        self.error = error
        self.deleteError = deleteError
    }

    func suspendNextSynchronization() {
        shouldSuspendNext = true
    }

    func resumeSynchronization() {
        suspendedContinuation?.resume()
        suspendedContinuation = nil
    }

    func setError(_ error: ViaError?) {
        self.error = error
    }

    func setDeleteError(_ error: ViaError?) {
        deleteError = error
    }

    func synchronize(_ operations: [AccountSyncOperation]) async throws -> AccountSyncResult {
        synchronizationCount += 1
        if shouldSuspendNext {
            shouldSuspendNext = false
            await withCheckedContinuation { suspendedContinuation = $0 }
        }
        if let error { throw error }
        operations.forEach(apply)
        return AccountSyncResult(
            appliedOperationIDs: operations.map(\.operationID),
            favorites: snapshot.favorites,
            recents: snapshot.recents,
            preferences: snapshot.preferences,
            syncedAt: .now
        )
    }

    func delete(using proof: AccountDeletionProof) throws {
        if let deleteError { throw deleteError }
        snapshot = AccountLocalSnapshot()
    }

    private func apply(_ operation: AccountSyncOperation) {
        switch operation.kind {
        case .favoriteUpsert:
            guard let favorite = operation.station else { return }
            snapshot.favorites.removeAll { $0.stationID == favorite.stationID }
            snapshot.favorites.insert(favorite, at: 0)
        case .favoriteRemove:
            snapshot.favorites.removeAll { $0.stationID == operation.stationID }
        case .recentUpsert:
            guard let recent = operation.recent else { return }
            snapshot.recents.removeAll { $0.id == recent.id }
            snapshot.recents.insert(recent, at: 0)
        case .recentClear:
            snapshot.recents.removeAll { $0.savedAt <= operation.occurredAt }
        case .preferencesSet:
            if let preferences = operation.preferences {
                snapshot.preferences = preferences
            }
        }
    }
}
