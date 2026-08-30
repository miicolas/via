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
        XCTAssertEqual(
            MapRoute(url: URL(string: "via://meetup/7D451D8A-42CA-4B54-9FE1-163A799372D3")!),
            .meetup("7d451d8a-42ca-4b54-9fe1-163a799372d3")
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

    func testParsesPublicJourneyLinksForUniversalLinksAndFallbackScheme() {
        let token = String(repeating: "A", count: 43)

        XCTAssertEqual(
            MapRoute(url: URL(string: "https://metyro.app/trip/\(token)")!),
            .sharedJourney(token)
        )
        XCTAssertEqual(
            MapRoute(url: URL(string: "via://trip/\(token)")!),
            .sharedJourney(token)
        )
        XCTAssertEqual(
            MapRoute(url: URL(string: "via://journey?mode=shared&token=\(token)")!),
            .sharedJourney(token)
        )
    }

    func testRecoversTokenFromLegacyShareLinkMessage() {
        let token = String(repeating: "A", count: 43)
        let message = " Voici un trajet partagé dans Metyro."
        let encodedMessage = message.addingPercentEncoding(withAllowedCharacters: .alphanumerics)!
        let doubleEncodedMessage = encodedMessage.addingPercentEncoding(
            withAllowedCharacters: .alphanumerics
        )!

        XCTAssertEqual(
            MapRoute(url: URL(string: "https://metyro.app/trip/\(token)\(encodedMessage)")!),
            .sharedJourney(token)
        )
        XCTAssertEqual(
            MapRoute(url: URL(string: "https://metyro.app/trip/\(token)\(doubleEncodedMessage)")!),
            .sharedJourney(token)
        )
    }

    func testParsesMeetupInvitationAndKeepsFragmentKeyOffTheServerPath() {
        let token = String(repeating: "M", count: 43)
        let key = String(repeating: "K", count: 43)

        XCTAssertEqual(
            MapRoute(url: URL(string: "https://metyro.app/meet/\(token)#k=\(key)")!),
            .meetupInvitation(token: token, key: key)
        )
        XCTAssertEqual(
            MapRoute(url: URL(string: "via://meet/\(token)#k=\(key)")!),
            .meetupInvitation(token: token, key: key)
        )
        XCTAssertEqual(
            MapRoute(url: URL(string: "https://metyro.app/meet/\(token)")!),
            .meetupInvitation(token: token, key: nil)
        )
    }

    func testRejectsMalformedMeetupInvitationTokenOrFragmentKey() {
        let token = String(repeating: "M", count: 43)

        XCTAssertNil(MapRoute(url: URL(string: "https://metyro.app/meet/short#k=\(token)")!))
        XCTAssertNil(MapRoute(url: URL(string: "https://metyro.app/meet/\(token)#k=short")!))
    }

    func testParsesFriendInvitationLinks() {
        let token = String(repeating: "F", count: 43)
        XCTAssertEqual(
            MapRoute(url: URL(string: "https://metyro.app/meet/friend/\(token)")!),
            .friendInvitation(token)
        )
        XCTAssertEqual(
            MapRoute(url: URL(string: "via://friend/\(token)")!),
            .friendInvitation(token)
        )
    }

    func testRejectsUnknownOrIncompleteRoutes() {
        XCTAssertNil(MapRoute(url: URL(string: "https://example.com")!))
        XCTAssertNil(MapRoute(url: URL(string: "https://metyro.app/trip/short")!))
        XCTAssertNil(MapRoute(url: URL(string: "via://journey/journey-1")!))
        XCTAssertNil(MapRoute(url: URL(string: "via://station")!))
    }
}
