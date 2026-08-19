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
        XCTAssertEqual(model.recentSearches.map(\.id), ["address:address"])
        XCTAssertEqual(model.transportPreferences.preferredModes, [.metro])
        XCTAssertEqual(model.syncState, .local)

        model.removeRecentSearch(id: "address:address")

        XCTAssertTrue(model.recentSearches.isEmpty)
    }

    @MainActor
    func testSavedPlacesReplaceTheirRoleAndSurviveRelaunch() {
        let date = Date(timeIntervalSince1970: 100)
        let model = AccountModel(
            store: AccountLocalStore(defaults: defaults),
            remote: AccountRemoteStub(),
            synchronizationEnabled: false,
            now: { date }
        )
        model.activate(userID: "user")

        model.setPlace(addressResult(id: "first-home"), role: .home)
        model.setPlace(addressResult(id: "work"), role: .work)
        model.setPlace(addressResult(id: "second-home"), role: .home)

        XCTAssertEqual(model.place(for: .home)?.id, "address:second-home")
        XCTAssertEqual(model.place(for: .work)?.id, "address:work")
        XCTAssertEqual(model.places.count, 2)

        let relaunched = AccountModel(
            store: AccountLocalStore(defaults: defaults),
            remote: AccountRemoteStub(),
            synchronizationEnabled: false
        )
        relaunched.activate(userID: "user")
        XCTAssertEqual(relaunched.place(for: .home)?.id, "address:second-home")

        relaunched.removePlace(id: "address:second-home")
        XCTAssertNil(relaunched.place(for: .home))
        XCTAssertEqual(relaunched.place(for: .work)?.id, "address:work")
    }

    @MainActor
    func testSavedPlaceMutationDuringSynchronizationSurvivesCanonicalMerge() async throws {
        let remote = AccountRemoteStub()
        await remote.suspendNextSynchronization()
        let model = AccountModel(
            store: AccountLocalStore(defaults: defaults),
            remote: remote
        )
        model.activate(userID: "user")
        await waitUntil { model.syncState == .syncing }

        model.setPlace(addressResult(id: "home"), role: .home)
        await remote.resumeSynchronization()
        await waitUntil {
            if case .synced = model.syncState { return true }
            return false
        }

        XCTAssertEqual(model.place(for: .home)?.id, "address:home")
    }

    @MainActor
    func testFavoriteKeepsItsCoordinate() {
        let model = AccountModel(
            store: AccountLocalStore(defaults: defaults),
            remote: AccountRemoteStub(),
            synchronizationEnabled: false
        )
        model.activate(userID: "user")
        let coordinate = GeoCoordinate(latitude: 48.88, longitude: 2.15)

        model.toggleFavorite(stationID: StationID(rawValue: "A"), name: "Chatou", coordinate: coordinate)

        XCTAssertEqual(model.favorites.first?.coordinate, coordinate)
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
        model.synchronize()
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
    func testAnonymousWorkspacePersistsAndMergesNewestValuesOnFirstLogin() {
        var currentDate = Date(timeIntervalSince1970: 100)
        let model = AccountModel(
            store: AccountLocalStore(defaults: defaults),
            remote: AccountRemoteStub(),
            synchronizationEnabled: false,
            now: { currentDate }
        )

        model.activate(userID: "user")
        model.toggleFavorite(stationID: StationID(rawValue: "A"), name: "Cloud")
        model.setPlace(addressResult(id: "cloud-home"), role: .home)
        model.recordRecentSearch(addressResult(id: "cloud-recent"))
        model.setPreferred(.metro, enabled: true)

        model.activateAnonymous()
        currentDate = Date(timeIntervalSince1970: 200)
        model.toggleFavorite(stationID: StationID(rawValue: "A"), name: "Appareil")
        model.setPlace(addressResult(id: "device-home"), role: .home)
        model.recordRecentSearch(addressResult(id: "device-recent"))
        model.setPreferred(.bus, enabled: true)

        let relaunched = AccountModel(
            store: AccountLocalStore(defaults: defaults),
            remote: AccountRemoteStub(),
            synchronizationEnabled: false
        )
        relaunched.activateAnonymous()
        XCTAssertEqual(relaunched.favorites.first?.name, "Appareil")

        relaunched.activate(userID: "user")
        XCTAssertEqual(relaunched.favorites.first?.name, "Appareil")
        XCTAssertEqual(relaunched.place(for: .home)?.id, "address:device-home")
        XCTAssertEqual(relaunched.transportPreferences.preferredModes, [.bus])
        XCTAssertTrue(relaunched.recentSearches.contains { $0.id == "address:device-recent" })
        XCTAssertNil(defaults.data(forKey: "via.account-data.v1.anonymous"))
    }

    @MainActor
    func testResetPreferencesKeepsFavoritesPlacesAndHistory() {
        let date = Date(timeIntervalSince1970: 100)
        let model = AccountModel(
            store: AccountLocalStore(defaults: defaults),
            remote: AccountRemoteStub(),
            synchronizationEnabled: false,
            now: { date }
        )
        model.activateAnonymous()
        model.toggleFavorite(stationID: StationID(rawValue: "A"), name: "Nation")
        model.setPlace(addressResult(id: "home"), role: .home)
        model.recordRecentSearch(addressResult(id: "recent"))
        model.setPreferred(.metro, enabled: true)

        model.resetPreferences()

        XCTAssertTrue(model.transportPreferences.preferredModes.isEmpty)
        XCTAssertEqual(model.favorites.count, 1)
        XCTAssertEqual(model.place(for: .home)?.id, "address:home")
        XCTAssertEqual(model.recentSearches.count, 1)
    }

    @MainActor
    func testEraseDeviceDataClearsTheLocalWorkspace() {
        let model = AccountModel(
            store: AccountLocalStore(defaults: defaults),
            remote: AccountRemoteStub(),
            synchronizationEnabled: false
        )
        model.activate(userID: "user")
        model.toggleFavorite(stationID: StationID(rawValue: "A"), name: "Nation")

        model.eraseDeviceData()

        XCTAssertTrue(model.isAnonymous)
        XCTAssertTrue(model.favorites.isEmpty)
        XCTAssertNil(defaults.data(forKey: "via.account-data.v1.user"))
        XCTAssertNotNil(defaults.data(forKey: "via.account-data.v1.anonymous"))
    }

    @MainActor
    func testEraseDeviceDataDoesNotResurfaceAnOlderAnonymousWorkspace() {
        let model = AccountModel(
            store: AccountLocalStore(defaults: defaults),
            remote: AccountRemoteStub(),
            synchronizationEnabled: false
        )
        model.activateAnonymous()
        model.toggleFavorite(stationID: StationID(rawValue: "OLD"), name: "Ancien")

        model.activate(userID: "user")
        model.toggleFavorite(stationID: StationID(rawValue: "CURRENT"), name: "Actuel")
        model.eraseDeviceData()

        XCTAssertTrue(model.isAnonymous)
        XCTAssertTrue(model.favorites.isEmpty)
        XCTAssertNil(defaults.data(forKey: "via.account-data.v1.user"))
        XCTAssertNotNil(defaults.data(forKey: "via.account-data.v1.anonymous"))
    }

    @MainActor
    func testExportContainsOnlyPortableAccountFields() throws {
        let model = AccountModel(
            store: AccountLocalStore(defaults: defaults),
            remote: AccountRemoteStub(),
            synchronizationEnabled: false
        )
        model.activateAnonymous()
        model.toggleFavorite(stationID: StationID(rawValue: "A"), name: "Nation")

        let data = try JSONEncoder.via.encode(
            model.makeExport(exportedAt: Date(timeIntervalSince1970: 100))
        )
        let object = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: data) as? [String: Any]
        )

        XCTAssertEqual(
            Set(object.keys),
            ["schemaVersion", "exportedAt", "favorites", "places", "recentSearches", "preferences"]
        )
        XCTAssertFalse(String(decoding: data, as: UTF8.self).contains("bearerToken"))
        XCTAssertFalse(String(decoding: data, as: UTF8.self).contains("appleUserIdentifier"))
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
            places: snapshot.places,
            preferences: snapshot.preferences,
            syncedAt: .now
        )
    }

    func delete(using proof: AccountDeletionProof) throws {
        if let deleteError { throw deleteError }
        snapshot = AccountLocalSnapshot()
    }

    private func apply(_ operation: AccountSyncOperation) {
        AccountOperationReducer.replay(operation, into: &snapshot)
    }
}
