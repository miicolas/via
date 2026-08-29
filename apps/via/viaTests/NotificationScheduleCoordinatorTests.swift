import Foundation
import UserNotifications
import XCTest
@testable import Via

@MainActor
final class NotificationScheduleCoordinatorTests: XCTestCase {
    private let mondayMorning = makeDate(year: 2026, month: 8, day: 24, hour: 7, minute: 0)

    func testAuthorizedReconciliationInstallsThreeUpcomingRequests() async {
        let center = ScheduleNotificationCenter(status: .authorized)
        let coordinator = NotificationScheduleCoordinator(center: center)

        await coordinator.reconcile(
            schedules: [makeSchedule()],
            preferences: .default,
            now: mondayMorning
        )

        XCTAssertEqual(center.requests.count, 3)
        XCTAssertTrue(center.requests.allSatisfy { $0.identifier.hasPrefix("via.schedule.commute.") })
        XCTAssertTrue(center.requests.allSatisfy { request in
            guard let trigger = request.trigger as? UNCalendarNotificationTrigger else { return false }
            return trigger.dateComponents.hour == 7 && trigger.dateComponents.minute == 50
        })
    }

    func testReconciliationAfterTheExistingOccurrencesReplacesThemWithFutureOnes() async {
        let center = ScheduleNotificationCenter(status: .authorized)
        let coordinator = NotificationScheduleCoordinator(center: center)
        let schedule = makeSchedule()

        await coordinator.reconcile(schedules: [schedule], preferences: .default, now: mondayMorning)
        let previous = Set(center.requests.map(\.identifier))

        await coordinator.reconcile(
            schedules: [schedule],
            preferences: .default,
            // Move beyond all three previously installed occurrences.
            now: makeDate(year: 2026, month: 8, day: 26, hour: 8, minute: 0)
        )

        XCTAssertEqual(center.requests.count, 3)
        XCTAssertTrue(previous.isDisjoint(with: center.requests.map(\.identifier)))
        let days = Set(center.requests.compactMap { request in
            (request.trigger as? UNCalendarNotificationTrigger)?.dateComponents.day
        })
        XCTAssertEqual(days, Set([27, 28, 31]))
    }

    func testRepeatedReconciliationAtTheSameInstantDoesNotDuplicateRequests() async {
        let center = ScheduleNotificationCenter(status: .authorized)
        let coordinator = NotificationScheduleCoordinator(center: center)

        await coordinator.reconcile(schedules: [makeSchedule()], preferences: .default, now: mondayMorning)
        await coordinator.reconcile(schedules: [makeSchedule()], preferences: .default, now: mondayMorning)

        XCTAssertEqual(center.requests.count, 3)
        XCTAssertEqual(Set(center.requests.map(\.identifier)).count, 3)
    }

    func testDeniedAuthorizationRemovesOldRequestsWithoutAddingNewOnes() async {
        let center = ScheduleNotificationCenter(status: .authorized)
        let coordinator = NotificationScheduleCoordinator(center: center)
        await coordinator.reconcile(schedules: [makeSchedule()], preferences: .default, now: mondayMorning)
        XCTAssertEqual(center.requests.count, 3)

        center.status = .denied
        await coordinator.reconcile(schedules: [makeSchedule()], preferences: .default, now: mondayMorning)

        XCTAssertTrue(center.requests.isEmpty)
        XCTAssertNotNil(coordinator.lastError)
    }

    func testAddFailureReportsRecoveryWhileTheScheduleRemainsIndependent() async {
        let center = ScheduleNotificationCenter(status: .authorized)
        center.addError = ScheduleNotificationError.addFailed
        let coordinator = NotificationScheduleCoordinator(center: center)

        await coordinator.reconcile(schedules: [makeSchedule()], preferences: .default, now: mondayMorning)

        XCTAssertNotNil(coordinator.lastError)
        XCTAssertTrue(center.requests.isEmpty)
    }

    func testConcurrentReconciliationKeepsOnlyTheLatestRevision() async {
        let center = ScheduleNotificationCenter(status: .authorized)
        center.suspendNextAdd = true
        let coordinator = NotificationScheduleCoordinator(center: center)
        let old = makeSchedule(departureMinute: 8 * 60)
        let revised = makeSchedule(departureMinute: 9 * 60)

        let first = Task {
            await coordinator.reconcile(
                schedules: [old],
                preferences: .default,
                now: mondayMorning
            )
        }
        await waitUntil { center.addStarted }

        let second = Task {
            await coordinator.reconcile(
                schedules: [revised],
                preferences: .default,
                now: mondayMorning
            )
        }
        await Task.yield()
        center.resumeSuspendedAdd()

        await first.value
        await second.value

        XCTAssertEqual(center.requests.count, 3)
        XCTAssertTrue(center.requests.allSatisfy { request in
            guard let trigger = request.trigger as? UNCalendarNotificationTrigger else { return false }
            return trigger.dateComponents.hour == 8 && trigger.dateComponents.minute == 50
        })
    }

    private func waitUntil(
        _ predicate: @escaping @MainActor () -> Bool,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        for _ in 0 ..< 200 {
            if predicate() { return }
            await Task.yield()
            try? await Task.sleep(for: .milliseconds(1))
        }
        XCTFail("Timed out waiting for notification center", file: file, line: line)
    }
}

@MainActor
private final class ScheduleNotificationCenter: JourneyNotificationCenterClient {
    var status: UNAuthorizationStatus
    var requests: [UNNotificationRequest] = []
    var removedIdentifiers: [String] = []
    var addError: Error?
    var suspendNextAdd = false
    private(set) var addStarted = false
    private var suspendedAdd: CheckedContinuation<Void, Error>?

    init(status: UNAuthorizationStatus) {
        self.status = status
    }

    func authorizationStatus() async -> UNAuthorizationStatus { status }

    func requestAuthorization() async throws -> Bool {
        status = .authorized
        return true
    }

    func add(_ request: UNNotificationRequest) async throws {
        if suspendNextAdd {
            suspendNextAdd = false
            addStarted = true
            try await withCheckedThrowingContinuation { continuation in
                suspendedAdd = continuation
            }
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

    func resumeSuspendedAdd() {
        suspendedAdd?.resume()
        suspendedAdd = nil
    }
}

private enum ScheduleNotificationError: Error {
    case addFailed
}

private func makeSchedule(
    id: String = "commute",
    departureMinute: Int = 8 * 60
) -> NotificationSchedule {
    let savedAt = makeDate(year: 2026, month: 8, day: 1, hour: 12, minute: 0)
    return NotificationSchedule(
        id: id,
        kind: .commute,
        label: "Domicile–travail",
        revision: 1,
        origin: nil,
        destination: nil,
        routeIDs: [],
        daysOfWeek: [1, 2, 3, 4, 5],
        departureMinute: departureMinute,
        leadMinutes: 10,
        skipHolidays: false,
        enabled: true,
        pausedUntil: nil,
        timeZone: "Europe/Paris",
        savedAt: savedAt,
        updatedAt: savedAt,
        deletedAt: nil
    )
}

private func makeDate(year: Int, month: Int, day: Int, hour: Int, minute: Int) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Paris")!
    return calendar.date(from: DateComponents(
        year: year,
        month: month,
        day: day,
        hour: hour,
        minute: minute
    ))!
}
