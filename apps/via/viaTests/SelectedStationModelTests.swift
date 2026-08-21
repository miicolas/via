import Foundation
import XCTest
@testable import Via

@MainActor
final class SelectedStationModelTests: XCTestCase {
    func testMapSelectionPublishesPlaceholderThenLoadsDepartures() async {
        let now = Date(timeIntervalSince1970: 2_000_000)
        let route = makeRoute(id: "metro-1", shortName: "1")
        let item = makeItem(id: "station", route: route)
        let board = DepartureBoard(
            source: .realtime,
            generatedAt: now,
            groups: [
                DepartureGroup(
                    route: route,
                    destination: "La Défense",
                    departures: [now.addingTimeInterval(300)]
                )
            ]
        )
        let model = makeModel(
            departures: DelayedSelectedDeparturesRepository(boards: [item.id: board]),
            now: now
        )

        model.select(item)

        XCTAssertEqual(model.overview?.id, item.id)
        XCTAssertEqual(model.overview?.departureSource, .unavailable)
        XCTAssertTrue(model.overview?.departures.isEmpty == true)
        XCTAssertEqual(model.overview?.accessibility?.condition, .autonomous)

        await waitUntil { model.overview?.departureSource == .realtime }

        XCTAssertEqual(model.overview?.departures.first?.destination, "La Défense")
        XCTAssertEqual(model.overview?.accessibility?.condition, .autonomous)
    }

    func testObsoleteDepartureResponseCannotReplaceNewSelection() async {
        let now = Date(timeIntervalSince1970: 2_000_000)
        let route = makeRoute(id: "metro-1", shortName: "1")
        let slow = makeItem(id: "slow", route: route)
        let current = makeItem(id: "current", route: route)
        let repository = DelayedSelectedDeparturesRepository(
            boards: [
                slow.id: DepartureBoard(source: .theoretical, generatedAt: now, groups: []),
                current.id: DepartureBoard(source: .realtime, generatedAt: now, groups: []),
            ],
            slowStationID: slow.id
        )
        let model = makeModel(departures: repository, now: now)

        model.select(slow)
        model.select(current)
        await waitUntil { model.overview?.departureSource == .realtime }
        try? await Task.sleep(for: .milliseconds(70))

        XCTAssertEqual(model.overview?.id, current.id)
        XCTAssertEqual(model.overview?.departureSource, .realtime)
    }

    func testFavoriteMutationIsPersistedByAccountModel() {
        let route = makeRoute(id: "metro-1", shortName: "1")
        let item = makeItem(id: "favorite", route: route)
        let (model, account) = makeModelAndAccount(
            departures: InMemoryDeparturesRepository()
        )
        model.select(item)

        XCTAssertFalse(model.isFavorite)
        XCTAssertTrue(model.toggleFavorite())
        XCTAssertTrue(account.isFavorite(stationID: item.id))
        XCTAssertTrue(model.isFavorite)

        XCTAssertFalse(model.toggleFavorite())
        XCTAssertFalse(account.isFavorite(stationID: item.id))
    }

    private func makeModel(
        departures: any DeparturesRepository,
        now: Date
    ) -> SelectedStationModel {
        makeModelAndAccount(departures: departures, now: now).0
    }

    private func makeModelAndAccount(
        departures: any DeparturesRepository,
        now: Date = .now
    ) -> (SelectedStationModel, AccountModel) {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let account = AccountModel(
            store: AccountLocalStore(defaults: defaults),
            remote: InMemoryAccountRemote(),
            synchronizationEnabled: false,
            now: { now }
        )
        account.activateAnonymous()
        let location = LocationModel(
            adapter: InMemoryLocationAdapter(
                coordinate: GeoCoordinate(latitude: 48.8566, longitude: 2.3522)
            )
        )
        return (
            SelectedStationModel(
                departuresRepository: departures,
                account: account,
                locationModel: location,
                now: { now }
            ),
            account
        )
    }

    private func makeRoute(id: String, shortName: String) -> RouteBadge {
        RouteBadge(
            id: RouteID(rawValue: id),
            shortName: shortName,
            mode: .metro,
            colorHex: "#FFBE00",
            textColorHex: "#000000"
        )
    }

    private func makeItem(id: String, route: RouteBadge) -> StationMapItem {
        StationMapItem(
            id: StationID(rawValue: id),
            name: id.capitalized,
            coordinate: GeoCoordinate(latitude: 48.8567, longitude: 2.3522),
            routes: [route],
            accessibility: StationAccessibility(
                condition: .autonomous,
                label: "En autonomie",
                comment: nil
            )
        )
    }

    private func waitUntil(
        _ predicate: @MainActor () -> Bool
    ) async {
        for _ in 0..<200 {
            if predicate() { return }
            try? await Task.sleep(for: .milliseconds(1))
        }
        XCTFail("Timed out waiting for selected station state")
    }
}

private actor DelayedSelectedDeparturesRepository: DeparturesRepository {
    let boards: [StationID: DepartureBoard]
    let slowStationID: StationID?

    init(
        boards: [StationID: DepartureBoard],
        slowStationID: StationID? = nil
    ) {
        self.boards = boards
        self.slowStationID = slowStationID
    }

    func board(stationID: StationID) async throws -> DepartureBoard {
        try await Task.sleep(
            for: stationID == slowStationID ? .milliseconds(50) : .milliseconds(2)
        )
        return boards[stationID]
            ?? DepartureBoard(source: .unavailable, generatedAt: .now, groups: [])
    }
}
