import XCTest
@testable import Via

final class MapRouteTests: XCTestCase {
    func testParsesNotificationAndResourceRoutes() {
        XCTAssertEqual(MapRoute(url: URL(string: "via://notifications")!), .notifications)
        XCTAssertEqual(
            MapRoute(url: URL(string: "via://line?routeId=metro-1")!),
            .line(RouteID(rawValue: "metro-1"))
        )
        XCTAssertEqual(
            MapRoute(url: URL(string: "via://station?stationId=stop-1")!),
            .station(StationID(rawValue: "stop-1"))
        )
    }

    func testParsesJourneyModesFromQueryOrPath() {
        XCTAssertEqual(
            MapRoute(url: URL(string: "via://journey/journey-1?mode=active")!),
            .activeJourney(JourneyID(rawValue: "journey-1"))
        )
        XCTAssertEqual(
            MapRoute(url: URL(string: "via://journey?journeyId=journey-2&mode=reminder")!),
            .scheduledJourney(JourneyID(rawValue: "journey-2"))
        )
    }

    func testRejectsUnknownOrIncompleteRoutes() {
        XCTAssertNil(MapRoute(url: URL(string: "https://example.com")!))
        XCTAssertNil(MapRoute(url: URL(string: "via://journey/journey-1")!))
        XCTAssertNil(MapRoute(url: URL(string: "via://station")!))
    }
}
