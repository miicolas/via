import Foundation
import UserNotifications
import XCTest
@testable import Via

@MainActor
final class JourneyNotificationTests: XCTestCase {
    func testPlannerBuildsDepartureConnectionsAndArrivalWithStableIdentifiers() {
        let departure = Date(timeIntervalSince1970: 1_787_000_000)
        let journey = makeJourney(departureAt: departure)
        let events = JourneyNotificationPlanner.events(
            for: journey,
            preferences: JourneyNotificationPreferences(),
            now: departure.addingTimeInterval(-3_600)
        )

        XCTAssertEqual(events.map(\.kind), [.departure, .connection, .arrival])
        XCTAssertEqual(events.map(\.id), ["departure", "connection-transit-2", "arrival"])
        XCTAssertEqual(events.map(\.requestIdentifier), [
            "via.journey.journey-1.departure",
            "via.journey.journey-1.connection-transit-2",
            "via.journey.journey-1.arrival",
        ])
        XCTAssertEqual(events[0].date, departure.addingTimeInterval(-600))
    }

    func testPlannerDropsPastEventsAndDeduplicatesSameTimestamps() {
        let departure = Date(timeIntervalSince1970: 1_787_000_000)
        let journey = makeJourney(departureAt: departure)
        let events = JourneyNotificationPlanner.events(
            for: journey,
            preferences: JourneyNotificationPreferences(
                departureLeadTime: .fiveMinutes
            ),
            now: departure.addingTimeInterval(1_500)
        )

        XCTAssertEqual(events.map(\.kind), [.arrival])
        XCTAssertTrue(events.allSatisfy { $0.date > departure.addingTimeInterval(1_500) })
    }

    func testDeniedPermissionKeepsTheReminderIntent() async {
        let center = FakeJourneyNotificationCenter(status: .denied)
        let store = InMemoryScheduledJourneyReminderStore()
        let coordinator = JourneyNotificationCoordinator(
            center: center,
            reminderStore: store,
            preferencesStore: InMemoryJourneyNotificationPreferencesStore(),
            now: { Date(timeIntervalSince1970: 1_787_000_000) }
        )
        let journey = makeJourney(departureAt: Date(timeIntervalSince1970: 1_787_000_000))

        await coordinator.scheduleReminder(
            for: journey,
            destination: .station(
                id: StationID(rawValue: "destination"),
                name: "Destination",
                coordinate: GeoCoordinate(latitude: 48.85, longitude: 2.35)
            ),
            source: .realtime
        )

        XCTAssertEqual(coordinator.reminder?.journey.id, journey.id)
        XCTAssertTrue(center.requests.isEmpty)
        XCTAssertNotNil(coordinator.lastError)
    }

    func testReplacingReminderCancelsThePreviousRequests() async {
        let center = FakeJourneyNotificationCenter(status: .authorized)
        let coordinator = JourneyNotificationCoordinator(
            center: center,
            reminderStore: InMemoryScheduledJourneyReminderStore(),
            preferencesStore: InMemoryJourneyNotificationPreferencesStore(),
            now: { Date(timeIntervalSince1970: 1_787_000_000) }
        )
        let first = makeJourney(
            id: JourneyID(rawValue: "first"),
            departureAt: Date(timeIntervalSince1970: 1_787_000_000)
        )
        let second = makeJourney(
            id: JourneyID(rawValue: "second"),
            departureAt: Date(timeIntervalSince1970: 1_787_000_000 + 7_200)
        )
        let destination = JourneyDestination.station(
            id: StationID(rawValue: "destination"),
            name: "Destination",
            coordinate: GeoCoordinate(latitude: 48.85, longitude: 2.35)
        )

        await coordinator.scheduleReminder(for: first, destination: destination, source: .realtime)
        await coordinator.scheduleReminder(for: second, destination: destination, source: .realtime)

        XCTAssertEqual(coordinator.reminder?.journey.id, second.id)
        XCTAssertEqual(center.removedIdentifiers, [
            "via.journey.first.departure",
            "via.journey.first.connection-transit-2",
            "via.journey.first.arrival",
        ])
    }

    private func makeJourney(
        id: JourneyID = JourneyID(rawValue: "journey-1"),
        departureAt: Date
    ) -> Journey {
        let firstRoute = JourneyRoute(
            id: RouteID(rawValue: "IDFM:C1"),
            shortName: "M1",
            longName: "Métro 1",
            mode: .metro,
            colorHex: "#FFCD00",
            textColorHex: "#000000"
        )
        let secondRoute = JourneyRoute(
            id: RouteID(rawValue: "IDFM:C2"),
            shortName: "M2",
            longName: "Métro 2",
            mode: .metro,
            colorHex: "#003CA6",
            textColorHex: "#FFFFFF"
        )
        let origin = JourneyPlace(
            name: "Origine",
            coordinate: GeoCoordinate(latitude: 48.85, longitude: 2.35)
        )
        let middle = JourneyPlace(
            name: "Correspondance",
            coordinate: GeoCoordinate(latitude: 48.86, longitude: 2.36)
        )
        let destination = JourneyPlace(
            name: "Destination",
            coordinate: GeoCoordinate(latitude: 48.87, longitude: 2.37)
        )
        let firstArrival = departureAt.addingTimeInterval(1_200)
        let secondDeparture = departureAt.addingTimeInterval(1_500)
        let secondArrival = departureAt.addingTimeInterval(2_700)
        return Journey(
            id: id,
            qualifier: .recommended,
            durationSeconds: 3_600,
            walkingDurationSeconds: 0,
            transferCount: 1,
            departureAt: departureAt,
            arrivalAt: departureAt.addingTimeInterval(3_600),
            status: .normal,
            warnings: [],
            sections: [
                JourneySection(
                    id: "transit-1",
                    kind: .transit,
                    durationSeconds: 1_200,
                    from: origin,
                    to: middle,
                    departureAt: departureAt,
                    arrivalAt: firstArrival,
                    geometry: [],
                    route: firstRoute,
                    direction: nil,
                    platform: nil,
                    stops: []
                ),
                JourneySection(
                    id: "transfer-1",
                    kind: .transfer,
                    durationSeconds: 300,
                    from: middle,
                    to: middle,
                    departureAt: nil,
                    arrivalAt: nil,
                    geometry: [],
                    route: nil,
                    direction: nil,
                    platform: nil,
                    stops: []
                ),
                JourneySection(
                    id: "transit-2",
                    kind: .transit,
                    durationSeconds: 1_200,
                    from: middle,
                    to: destination,
                    departureAt: secondDeparture,
                    arrivalAt: secondArrival,
                    geometry: [],
                    route: secondRoute,
                    direction: nil,
                    platform: nil,
                    stops: []
                ),
            ]
        )
    }
}

@MainActor
private final class FakeJourneyNotificationCenter: JourneyNotificationCenterClient {
    var status: UNAuthorizationStatus
    var requests: [UNNotificationRequest] = []
    var removedIdentifiers: [String] = []

    init(status: UNAuthorizationStatus) {
        self.status = status
    }

    func authorizationStatus() async -> UNAuthorizationStatus { status }

    func requestAuthorization() async throws -> Bool {
        status = .authorized
        return true
    }

    func add(_ request: UNNotificationRequest) async throws {
        requests.append(request)
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        removedIdentifiers.append(contentsOf: identifiers)
    }
}
