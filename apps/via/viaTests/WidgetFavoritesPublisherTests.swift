import XCTest
@testable import Via

final class WidgetFavoritesPublisherTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "dev.via.widget-favorites-tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    @MainActor
    func testPublishingWritesWhatTheWidgetsRead() {
        let store = WidgetFavoritesStore(defaults: defaults)
        let reloads = ReloadCounter()
        let publisher = WidgetFavoritesPublisher(
            store: store,
            reloadWidgets: { reloads.increment() },
            now: { Date(timeIntervalSince1970: 1_000) }
        )

        publisher.publish(
            places: [],
            destinations: [destination(label: "Sport")],
            lines: [status(shortName: "A", condition: .disrupted)],
            linesFetchedAt: Date(timeIntervalSince1970: 900)
        )

        let snapshot = store.read()
        XCTAssertEqual(snapshot.journeys.map(\.label), ["Sport"])
        XCTAssertEqual(snapshot.lines.map(\.shortName), ["A"])
        XCTAssertEqual(snapshot.capturedAt, Date(timeIntervalSince1970: 1_000))
        XCTAssertEqual(snapshot.linesFetchedAt, Date(timeIntervalSince1970: 900))
        XCTAssertEqual(reloads.value, 1)
    }

    /// Widgets get a refresh budget from the system. Re-publishing an unchanged
    /// snapshot — which the shell does whenever a screen re-evaluates — must
    /// not spend it.
    @MainActor
    func testAnUnchangedSnapshotDoesNotReloadTheWidgets() {
        let store = WidgetFavoritesStore(defaults: defaults)
        let reloads = ReloadCounter()
        var clock = Date(timeIntervalSince1970: 1_000)
        let publisher = WidgetFavoritesPublisher(
            store: store,
            reloadWidgets: { reloads.increment() },
            now: { clock }
        )
        let lines = [status(shortName: "A", condition: .disrupted)]

        publisher.publish(places: [], destinations: [], lines: lines, linesFetchedAt: nil)
        clock = Date(timeIntervalSince1970: 2_000)
        publisher.publish(places: [], destinations: [], lines: lines, linesFetchedAt: nil)

        XCTAssertEqual(reloads.value, 1)

        clock = Date(timeIntervalSince1970: 3_000)
        publisher.publish(
            places: [],
            destinations: [],
            lines: [status(shortName: "A", condition: .suspended)],
            linesFetchedAt: nil
        )

        XCTAssertEqual(reloads.value, 2)
    }

    /// A cold launch reaches the shell before the Lignes board answers. The
    /// widget must keep showing what it had rather than blanking until the
    /// first response lands.
    @MainActor
    func testABoardThatNeverLoadedKeepsTheLastPublishedLines() {
        let store = WidgetFavoritesStore(defaults: defaults)
        let reloads = ReloadCounter()
        let publisher = WidgetFavoritesPublisher(
            store: store,
            reloadWidgets: { reloads.increment() },
            now: { Date(timeIntervalSince1970: 1_000) }
        )

        publisher.publish(
            places: [],
            destinations: [],
            lines: [status(shortName: "A", condition: .disrupted)],
            linesFetchedAt: Date(timeIntervalSince1970: 900)
        )
        publisher.publish(places: [], destinations: [], lines: [], linesFetchedAt: nil)

        XCTAssertEqual(store.read().lines.map(\.shortName), ["A"])
        XCTAssertEqual(store.read().linesFetchedAt, Date(timeIntervalSince1970: 900))
        XCTAssertEqual(reloads.value, 1)
    }

    /// Once the board *has* answered, an empty list is the traveller removing
    /// their last saved line, and the widget has to follow.
    @MainActor
    func testRemovingTheLastSavedLineEmptiesTheWidget() {
        let store = WidgetFavoritesStore(defaults: defaults)
        let reloads = ReloadCounter()
        let publisher = WidgetFavoritesPublisher(
            store: store,
            reloadWidgets: { reloads.increment() },
            now: { Date(timeIntervalSince1970: 1_000) }
        )

        publisher.publish(
            places: [],
            destinations: [],
            lines: [status(shortName: "A", condition: .disrupted)],
            linesFetchedAt: Date(timeIntervalSince1970: 900)
        )
        publisher.publish(
            places: [],
            destinations: [],
            lines: [],
            linesFetchedAt: Date(timeIntervalSince1970: 950)
        )

        XCTAssertTrue(store.read().lines.isEmpty)
        XCTAssertEqual(reloads.value, 2)
    }

    /// A build that lost the App Group entitlement still runs; the widgets then
    /// draw their empty state instead of the extension crashing.
    func testAMissingAppGroupReadsAsAnEmptySnapshot() {
        let store = WidgetFavoritesStore(defaults: nil)

        XCTAssertFalse(store.write(WidgetFavoritesSnapshot(capturedAt: .now)))
        XCTAssertEqual(store.read(), .empty)
    }

    private func destination(label: String) -> SavedDestination {
        SavedDestination(
            result: .address(AddressSearchResult(
                id: "address-\(label)",
                name: "Adresse \(label)",
                context: "Paris",
                coordinate: GeoCoordinate(latitude: 48.86, longitude: 2.36),
                distanceMeters: nil
            )),
            label: label,
            systemImage: "dumbbell.fill",
            position: 0,
            savedAt: .distantPast
        )
    }

    private func status(shortName: String, condition: LineCondition) -> LineStatus {
        LineStatus(
            route: RouteBadge(
                id: RouteID(rawValue: "route-\(shortName)"),
                shortName: shortName,
                mode: .rer,
                colorHex: "#E3051C",
                textColorHex: "#FFFFFF"
            ),
            condition: condition,
            summary: nil,
            activeCount: 1,
            upcoming: nil
        )
    }
}

private final class ReloadCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0

    func increment() {
        lock.withLock { count += 1 }
    }

    var value: Int {
        lock.withLock { count }
    }
}
