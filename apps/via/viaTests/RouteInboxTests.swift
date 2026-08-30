import Foundation
import XCTest
@testable import Via

@MainActor
final class RouteInboxTests: XCTestCase {
    func testBuffersARouteUntilAConsumerExists() {
        let inbox = RouteInbox()
        XCTAssertNil(inbox.pending)

        inbox.receive(MapRoute.notifications)

        XCTAssertEqual(inbox.pending, .notifications)
        XCTAssertEqual(inbox.consume(), .notifications)
    }

    func testConsumeHandsOverExactlyOnce() {
        let inbox = RouteInbox()
        inbox.receive(MapRoute.station(StationID(rawValue: "stop-1")))

        XCTAssertEqual(inbox.consume(), .station(StationID(rawValue: "stop-1")))
        XCTAssertNil(inbox.consume())
        XCTAssertNil(inbox.pending)
    }

    func testUniversalLinkAndPushRouteEnterTheSameFunnel() {
        let inbox = RouteInbox()
        let token = String(repeating: "A", count: 43)

        // A universal link, as onOpenURL hands it over.
        inbox.receive(URL(string: "https://metyro.app/trip/\(token)")!)
        XCTAssertEqual(inbox.consume(), .sharedJourney(token))

        // A push notification's route, as the manager stores it.
        inbox.receive(URL(string: "via://journey?journeyId=journey-1&mode=active")!)
        XCTAssertEqual(inbox.consume(), .activeJourney(JourneyID(rawValue: "journey-1")))
    }

    func testForeignURLLeavesTheInboxEmpty() {
        let inbox = RouteInbox()

        inbox.receive(URL(string: "https://example.com/trip/whatever")!)

        XCTAssertNil(inbox.pending)
    }

    func testLatestRouteReplacesTheBufferedOne() {
        let inbox = RouteInbox()
        inbox.receive(MapRoute.notifications)
        inbox.receive(MapRoute.line(RouteID(rawValue: "metro-1")))

        XCTAssertEqual(inbox.consume(), .line(RouteID(rawValue: "metro-1")))
        XCTAssertNil(inbox.consume())
    }
}
