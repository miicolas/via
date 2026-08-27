import XCTest
@testable import Via

/// The extension builds these links and the app parses them. Nothing fails to
/// build when the two drift — it ships a widget that opens Metyro on nothing —
/// so every builder is round-tripped through the parser here.
final class ViaWidgetLinkTests: XCTestCase {
    func testEveryWidgetLinkIsARouteTheAppUnderstands() {
        XCTAssertEqual(MapRoute(url: ViaWidgetLink.lines), .lines)
        XCTAssertEqual(MapRoute(url: ViaWidgetLink.search), .search)
        XCTAssertEqual(
            MapRoute(url: ViaWidgetLink.line(routeID: "metro-1")),
            .line(RouteID(rawValue: "metro-1"))
        )
    }

    func testFavoriteJourneyLinkCarriesBothPlaceAndDestinationTokens() {
        let destinationID = UUID()

        XCTAssertEqual(
            MapRoute(url: ViaWidgetLink.favoriteJourney(id: "place:home")),
            .favoriteJourney("place:home")
        )
        XCTAssertEqual(
            MapRoute(url: ViaWidgetLink.favoriteJourney(id: destinationID.uuidString)),
            .favoriteJourney(destinationID.uuidString)
        )
    }

    /// The favourite branch must not swallow the journey modes that shared the
    /// `journey` host before it.
    func testFavoriteModeLeavesTheOtherJourneyModesAlone() {
        XCTAssertEqual(
            MapRoute(url: URL(string: "via://journey?journeyId=journey-1&mode=active")!),
            .activeJourney(JourneyID(rawValue: "journey-1"))
        )
        XCTAssertEqual(
            MapRoute(url: URL(string: "via://journey?journeyId=journey-2&mode=reminder")!),
            .scheduledJourney(JourneyID(rawValue: "journey-2"))
        )
        XCTAssertNil(MapRoute(url: URL(string: "via://journey?mode=favorite")!))
        XCTAssertNil(MapRoute(url: URL(string: "via://journey?mode=favorite&favoriteId=")!))
    }
}
