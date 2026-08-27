import XCTest
@testable import Via

final class WidgetFavoritesProjectionTests: XCTestCase {
    func testHomeAndWorkLeadThenSavedDestinationsInTheirOwnOrder() {
        let journeys = WidgetFavoritesProjection.journeys(
            places: [place(role: .work), place(role: .home)],
            destinations: [destination(label: "Sport", position: 1), destination(label: "Gare", position: 0)]
        )

        XCTAssertEqual(journeys.map(\.label), ["Maison", "Travail", "Gare", "Sport"])
        XCTAssertEqual(journeys[0].id, "place:home")
        XCTAssertEqual(journeys[1].id, "place:work")
    }

    func testAFavouriteTokenResolvesBackToTheDestinationItNames() {
        let home = place(role: .home)
        let saved = destination(label: "Sport", position: 0)

        XCTAssertEqual(
            WidgetFavoriteToken.searchResult(
                for: WidgetFavoriteToken.token(for: home),
                places: [home],
                destinations: [saved]
            )?.name,
            home.name
        )
        XCTAssertEqual(
            WidgetFavoriteToken.searchResult(
                for: WidgetFavoriteToken.token(for: saved),
                places: [home],
                destinations: [saved]
            )?.name,
            saved.name
        )
    }

    /// A favourite deleted after the widget was configured resolves to nothing
    /// rather than to somebody else's destination.
    func testAnUnknownTokenResolvesToNothing() {
        XCTAssertNil(
            WidgetFavoriteToken.searchResult(
                for: UUID().uuidString,
                places: [],
                destinations: [destination(label: "Sport", position: 0)]
            )
        )
        XCTAssertNil(
            WidgetFavoriteToken.searchResult(for: "place:garage", places: [], destinations: [])
        )
        XCTAssertNil(
            WidgetFavoriteToken.searchResult(for: "not-a-uuid", places: [], destinations: [])
        )
    }

    func testLinesAreOrderedWorstFirstAndKeepTheSavedOrderOnTies() {
        let lines = WidgetFavoritesProjection.lines([
            status(shortName: "1", condition: .normal),
            status(shortName: "A", condition: .disrupted),
            status(shortName: "4", condition: .normal),
            status(shortName: "B", condition: .suspended),
            status(shortName: "T3a", condition: .attention),
        ])

        XCTAssertEqual(lines.map(\.shortName), ["B", "A", "T3a", "1", "4"])
    }

    func testUpcomingClosureCrossesAsAFlagAndSummaryIsCarried() {
        let lines = WidgetFavoritesProjection.lines([
            status(
                shortName: "1",
                condition: .normal,
                upcoming: UpcomingClosure(beginsAt: .now, title: "Travaux")
            ),
            status(shortName: "A", condition: .disrupted, summary: "Incident voyageur"),
        ])

        XCTAssertEqual(lines.first?.summary, "Incident voyageur")
        XCTAssertFalse(lines.first?.hasUpcomingClosure ?? true)
        XCTAssertTrue(lines.last?.hasUpcomingClosure ?? false)
    }

    /// The widget extension links neither `LineCondition` nor `TransitMode`, so
    /// both are declared a second time in `ViaWidgetShared`. These pin the two
    /// copies together: a case added on one side has to be added on the other.
    func testWidgetConditionsMirrorTheAppsOwn() {
        XCTAssertEqual(
            LineCondition.allCases.map(\.rawValue),
            WidgetLineCondition.allCases.map(\.rawValue)
        )

        for condition in LineCondition.allCases {
            let widget = WidgetLineCondition(rawValue: condition.rawValue)
            XCTAssertEqual(widget?.title, condition.title)
            XCTAssertEqual(widget?.systemImage, condition.systemImage)
            XCTAssertEqual(widget?.displayPriority, condition.displayPriority)
        }
    }

    func testWidgetModeNamesMirrorTheAppsOwn() {
        for mode in TransitMode.allCases {
            XCTAssertEqual(
                WidgetTransitModeName.french(forMode: mode.rawValue),
                mode.displayName
            )
        }
    }

    private func place(role: SavedPlace.Role) -> SavedPlace {
        SavedPlace(
            result: .address(AddressSearchResult(
                id: "address-\(role.rawValue)",
                name: "Adresse \(role.rawValue)",
                context: "Paris",
                coordinate: GeoCoordinate(latitude: 48.85, longitude: 2.35),
                distanceMeters: nil
            )),
            role: role,
            savedAt: .distantPast
        )
    }

    private func destination(label: String, position: Int) -> SavedDestination {
        SavedDestination(
            result: .address(AddressSearchResult(
                id: "address-\(label)",
                name: "Adresse \(label)",
                context: "Paris",
                coordinate: GeoCoordinate(latitude: 48.86, longitude: 2.36),
                distanceMeters: nil
            )),
            label: label,
            systemImage: "mappin",
            position: position,
            savedAt: .distantPast
        )
    }

    private func status(
        shortName: String,
        condition: LineCondition,
        summary: String? = nil,
        upcoming: UpcomingClosure? = nil
    ) -> LineStatus {
        LineStatus(
            route: RouteBadge(
                id: RouteID(rawValue: "route-\(shortName)"),
                shortName: shortName,
                mode: .metro,
                colorHex: "#FFCD00",
                textColorHex: "#000000"
            ),
            condition: condition,
            summary: summary,
            activeCount: condition == .normal ? 0 : 1,
            upcoming: upcoming
        )
    }
}
