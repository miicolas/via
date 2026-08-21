@testable import Via
import XCTest

final class RecentSearchStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "dev.via.recent-search-store-tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testPersistsDeduplicatesOrdersAndLimitsRecents() {
        let store = UserDefaultsRecentSearchStore(defaults: defaults)
        for index in 0 ..< 6 {
            _ = store.upsert(recent(id: "\(index)", savedAt: Date(timeIntervalSince1970: Double(index))))
        }

        _ = store.upsert(recent(id: "3", savedAt: Date(timeIntervalSince1970: 10)))
        let relaunched = UserDefaultsRecentSearchStore(defaults: defaults)

        XCTAssertEqual(relaunched.load().map(\.resultIdentifier), ["3", "5", "4", "2", "1"])
    }

    func testRemovesOneRecentAndClearsAllRecents() {
        let store = UserDefaultsRecentSearchStore(defaults: defaults)
        _ = store.upsert(recent(id: "first", savedAt: .distantPast))
        _ = store.upsert(recent(id: "second", savedAt: .now))

        XCTAssertEqual(store.remove(id: "address:second").map(\.resultIdentifier), ["first"])
        XCTAssertTrue(store.clear().isEmpty)
        XCTAssertTrue(store.load().isEmpty)
    }

    func testCorruptedPayloadStartsWithAnEmptyHistory() {
        defaults.set(Data("not-json".utf8), forKey: "via.local-recent-searches.v1")

        XCTAssertTrue(UserDefaultsRecentSearchStore(defaults: defaults).load().isEmpty)
    }

    private func recent(id: String, savedAt: Date) -> RecentSearch {
        RecentSearch(
            result: .address(AddressSearchResult(
                id: id,
                name: "Adresse \(id)",
                context: "Paris",
                coordinate: GeoCoordinate(latitude: 48.85, longitude: 2.35),
                distanceMeters: nil
            )),
            savedAt: savedAt
        )
    }
}
