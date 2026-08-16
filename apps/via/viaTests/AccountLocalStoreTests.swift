import XCTest
@testable import Via

final class AccountLocalStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "dev.via.tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testActivationMigratesLegacyRecentsOnlyOnce() throws {
        let recent = makeRecent(id: "first", date: Date(timeIntervalSince1970: 10))
        defaults.set(try JSONEncoder.via.encode([recent]), forKey: "via.recent-searches.v1")
        let store = AccountLocalStore(defaults: defaults)

        store.activate(userID: "user-1")

        XCTAssertEqual(store.recents(), [recent])
        XCTAssertNil(defaults.data(forKey: "via.recent-searches.v1"))
        XCTAssertEqual(store.pendingSync()?.operations.count, 1)

        store.deactivate()
        store.activate(userID: "user-2")
        XCTAssertTrue(store.recents().isEmpty)
    }

    func testCanonicalResponseDoesNotEraseANewerPendingMutation() {
        let store = AccountLocalStore(defaults: defaults)
        store.activate(userID: "user")
        _ = store.toggleFavorite(stationID: StationID(rawValue: "A"), name: "A")
        let firstOperation = store.pendingSync()!.operations[0]
        _ = store.toggleFavorite(stationID: StationID(rawValue: "B"), name: "B")

        store.apply(AccountSyncResult(
            appliedOperationIDs: [firstOperation.operationID],
            favorites: [],
            recents: [],
            preferences: .empty,
            syncedAt: .now
        ))

        XCTAssertEqual(store.favorites().map(\.stationID), ["B"])
        XCTAssertEqual(store.pendingSync()?.operations.count, 1)
    }

    func testFavoritesStayWithinTheOfflineLimit() {
        let store = AccountLocalStore(defaults: defaults)
        store.activate(userID: "user")

        for index in 0..<51 {
            _ = store.toggleFavorite(
                stationID: StationID(rawValue: "station-\(index)"),
                name: "Station \(index)"
            )
        }

        XCTAssertEqual(store.favorites().count, 50)
        XCTAssertFalse(store.favorites().contains { $0.stationID == "station-0" })
    }

    private func makeRecent(id: String, date: Date) -> RecentSearch {
        RecentSearch(
            result: .address(AddressSearchResult(
                id: id,
                name: id,
                context: "Paris",
                coordinate: GeoCoordinate(latitude: 48.85, longitude: 2.35),
                distanceMeters: nil
            )),
            savedAt: date
        )
    }
}
