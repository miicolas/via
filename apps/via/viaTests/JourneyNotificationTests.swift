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

    func testScheduledJourneyNotificationsAreTimeSensitive() async {
        let now = Date(timeIntervalSince1970: 1_787_000_000)
        let center = FakeJourneyNotificationCenter(status: .authorized)
        let coordinator = JourneyNotificationCoordinator(
            center: center,
            reminderStore: InMemoryScheduledJourneyReminderStore(),
            preferencesStore: InMemoryJourneyNotificationPreferencesStore(),
            now: { now }
        )

        await coordinator.scheduleReminder(
            for: makeJourney(departureAt: now.addingTimeInterval(3_600)),
            destination: makeDestination(),
            source: .realtime
        )

        XCTAssertFalse(center.requests.isEmpty)
        XCTAssertTrue(
            center.requests.allSatisfy { $0.content.interruptionLevel == .timeSensitive }
        )
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
        let destination = makeDestination()

        await coordinator.scheduleReminder(for: first, destination: destination, source: .realtime)
        await coordinator.scheduleReminder(for: second, destination: destination, source: .realtime)

        XCTAssertEqual(coordinator.reminder?.journey.id, second.id)
        XCTAssertEqual(center.removedIdentifiers, [
            "via.journey.first.connection-transit-2",
            "via.journey.first.arrival",
        ])
    }

    func testAddFailureKeepsIntentWithoutClaimingTheReminderIsScheduled() async {
        let center = FakeJourneyNotificationCenter(status: .authorized)
        center.addError = FakeNotificationError.addFailed
        let coordinator = JourneyNotificationCoordinator(
            center: center,
            reminderStore: InMemoryScheduledJourneyReminderStore(),
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
        XCTAssertNil(coordinator.scheduledJourneyID)
        XCTAssertNotNil(coordinator.lastError)
    }

    func testPartialReplacementFailureRollsBackToPreviousRequests() async {
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
            departureAt: Date(timeIntervalSince1970: 1_787_007_200)
        )
        let destination = makeDestination()

        await coordinator.scheduleReminder(
            for: first,
            destination: destination,
            source: .realtime
        )
        center.failOnAddAttempt = center.addAttempts + 2
        await coordinator.scheduleReminder(
            for: second,
            destination: destination,
            source: .realtime
        )

        XCTAssertEqual(
            Set(center.requests.map(\.identifier)),
            Set([
                "via.journey.first.connection-transit-2",
                "via.journey.first.arrival",
            ])
        )
        XCTAssertEqual(coordinator.scheduledJourneyID, first.id)
        XCTAssertNotNil(coordinator.lastError)
    }

    func testArrivalDeepLinkIntentSurvivesReconciliationForOneDay() async {
        let store = InMemoryScheduledJourneyReminderStore()
        let departure = Date(timeIntervalSince1970: 1_787_000_000)
        let journey = makeJourney(departureAt: departure)
        let destination = makeDestination()
        let initial = JourneyNotificationCoordinator(
            center: FakeJourneyNotificationCenter(status: .authorized),
            reminderStore: store,
            preferencesStore: InMemoryJourneyNotificationPreferencesStore(),
            now: { departure.addingTimeInterval(-3_600) }
        )
        await initial.scheduleReminder(for: journey, destination: destination, source: .realtime)

        let restored = JourneyNotificationCoordinator(
            center: FakeJourneyNotificationCenter(status: .authorized),
            reminderStore: store,
            preferencesStore: InMemoryJourneyNotificationPreferencesStore(),
            now: { journey.arrivalAt.addingTimeInterval(60) }
        )
        await restored.restore()

        XCTAssertEqual(restored.reminder(for: journey.id)?.journey.id, journey.id)
        XCTAssertNil(restored.scheduledJourneyID)
    }

    func testUnreadableStoreRemovesOnlyOrphanedViaRequests() async {
        let center = FakeJourneyNotificationCenter(status: .authorized)
        center.requests = [
            UNNotificationRequest(
                identifier: "via.journey.orphan.arrival",
                content: UNMutableNotificationContent(),
                trigger: nil
            ),
            UNNotificationRequest(
                identifier: "another-feature.notification",
                content: UNMutableNotificationContent(),
                trigger: nil
            ),
        ]
        let store = FailingScheduledJourneyReminderStore(loadError: .loadFailed)
        let coordinator = JourneyNotificationCoordinator(
            center: center,
            reminderStore: store,
            preferencesStore: InMemoryJourneyNotificationPreferencesStore()
        )

        await coordinator.restore()

        XCTAssertEqual(center.requests.map(\.identifier), ["another-feature.notification"])
        XCTAssertEqual(center.removedIdentifiers, ["via.journey.orphan.arrival"])
        let wasCleared = await store.wasCleared
        XCTAssertTrue(wasCleared)
        XCTAssertNotNil(coordinator.lastError)
    }

    func testMissingStoreRemovesOrphanedViaRequestsAfterInterruptedCancellation() async {
        let center = FakeJourneyNotificationCenter(status: .authorized)
        center.requests = [
            UNNotificationRequest(
                identifier: "via.journey.cancelled.arrival",
                content: UNMutableNotificationContent(),
                trigger: nil
            ),
        ]
        let coordinator = JourneyNotificationCoordinator(
            center: center,
            reminderStore: InMemoryScheduledJourneyReminderStore(),
            preferencesStore: InMemoryJourneyNotificationPreferencesStore()
        )

        await coordinator.restore()

        XCTAssertTrue(center.requests.isEmpty)
        XCTAssertEqual(center.removedIdentifiers, ["via.journey.cancelled.arrival"])
    }

    func testClearFailureKeepsReminderAndPendingRequests() async {
        let center = FakeJourneyNotificationCenter(status: .authorized)
        let store = FailingScheduledJourneyReminderStore()
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
        await store.failClearing()

        await coordinator.cancelReminder()

        XCTAssertEqual(coordinator.reminder?.journey.id, journey.id)
        XCTAssertEqual(coordinator.scheduledJourneyID, journey.id)
        XCTAssertFalse(center.requests.isEmpty)
        XCTAssertNotNil(coordinator.lastError)
    }

    func testJourneyRevisionRebuildsReminderEventsAndPreservesPlanningPolicy() async {
        let now = Date(timeIntervalSince1970: 1_787_000_000)
        let center = FakeJourneyNotificationCenter(status: .authorized)
        let coordinator = JourneyNotificationCoordinator(
            center: center,
            reminderStore: InMemoryScheduledJourneyReminderStore(),
            preferencesStore: InMemoryJourneyNotificationPreferencesStore(),
            now: { now }
        )
        let original = makeJourney(departureAt: now.addingTimeInterval(3_600))
        let revised = makeJourney(departureAt: now.addingTimeInterval(3_900))
        let policy = JourneyPlanningPolicy(preferredModes: [.metro])
        await coordinator.scheduleReminder(
            for: original,
            destination: makeDestination(),
            source: .realtime,
            planningPolicy: policy
        )

        await coordinator.applyJourneyRevision(revised)

        XCTAssertEqual(coordinator.reminder?.journey, revised)
        XCTAssertEqual(coordinator.reminder?.planningPolicy, policy)
        XCTAssertEqual(
            coordinator.reminder?.events.first?.date,
            revised.departureAt.addingTimeInterval(-600)
        )
        XCTAssertEqual(coordinator.scheduledJourneyID, revised.id)
    }

    private func makeDestination() -> JourneyDestination {
        .station(
            id: StationID(rawValue: "destination"),
            name: "Destination",
            coordinate: GeoCoordinate(latitude: 48.85, longitude: 2.35)
        )
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
    var addError: Error?
    var addAttempts = 0
    var failOnAddAttempt: Int?

    init(status: UNAuthorizationStatus) {
        self.status = status
    }

    func authorizationStatus() async -> UNAuthorizationStatus { status }

    func requestAuthorization() async throws -> Bool {
        status = .authorized
        return true
    }

    func add(_ request: UNNotificationRequest) async throws {
        addAttempts += 1
        if failOnAddAttempt == addAttempts {
            failOnAddAttempt = nil
            throw FakeNotificationError.addFailed
        }
        if let addError { throw addError }
        requests.removeAll { $0.identifier == request.identifier }
        requests.append(request)
    }

    func pendingNotificationRequests() async -> [UNNotificationRequest] { requests }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        removedIdentifiers.append(contentsOf: identifiers)
        let removed = Set(identifiers)
        requests.removeAll { removed.contains($0.identifier) }
    }
}

private enum FakeNotificationError: Error {
    case addFailed
}

private actor FailingScheduledJourneyReminderStore: ScheduledJourneyReminderStoring {
    private var reminder: ScheduledJourneyReminder?
    private var clearError: FakeStoreError?
    private let loadError: FakeStoreError?
    private(set) var wasCleared = false

    init(loadError: FakeStoreError? = nil) {
        self.loadError = loadError
    }

    func load() throws -> ScheduledJourneyReminder? {
        if let loadError { throw loadError }
        return reminder
    }

    func save(_ reminder: ScheduledJourneyReminder) {
        self.reminder = reminder
    }

    func clear() throws {
        if let clearError { throw clearError }
        reminder = nil
        wasCleared = true
    }

    func failClearing() {
        clearError = .clearFailed
    }
}

private enum FakeStoreError: Error {
    case loadFailed
    case clearFailed
}
