import Foundation
import Observation
import UserNotifications

@MainActor
protocol JourneyNotificationCenterClient: AnyObject {
    func authorizationStatus() async -> UNAuthorizationStatus
    func requestAuthorization() async throws -> Bool
    func add(_ request: UNNotificationRequest) async throws
    func removePendingNotificationRequests(withIdentifiers identifiers: [String])
}

@MainActor
final class SystemJourneyNotificationCenter: JourneyNotificationCenterClient {
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    func requestAuthorization() async throws -> Bool {
        try await center.requestAuthorization(options: [.alert, .badge, .sound])
    }

    func add(_ request: UNNotificationRequest) async throws {
        try await center.add(request)
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }
}

@MainActor
protocol JourneyNotificationActiveJourneyManaging: AnyObject {
    func registerActiveJourney(_ journey: Journey) async
    func unregisterActiveJourney(_ journey: Journey) async
}

@MainActor
final class NoOpJourneyNotificationActiveJourneyManager: JourneyNotificationActiveJourneyManaging {
    func registerActiveJourney(_ journey: Journey) async {}
    func unregisterActiveJourney(_ journey: Journey) async {}
}

@MainActor
@Observable
final class JourneyNotificationCoordinator {
    static let preview = JourneyNotificationCoordinator(
        center: PreviewJourneyNotificationCenter(),
        reminderStore: InMemoryScheduledJourneyReminderStore(),
        preferencesStore: InMemoryJourneyNotificationPreferencesStore()
    )

    private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    private(set) var reminder: ScheduledJourneyReminder?
    private(set) var lastError: String?
    private(set) var preferences: JourneyNotificationPreferences

    @ObservationIgnored private let center: any JourneyNotificationCenterClient
    @ObservationIgnored private let reminderStore: any ScheduledJourneyReminderStoring
    @ObservationIgnored private let preferencesStore: any JourneyNotificationPreferencesStoring
    @ObservationIgnored private let activeJourneyManager: any JourneyNotificationActiveJourneyManaging
    @ObservationIgnored private let now: @Sendable () -> Date

    init(
        center: any JourneyNotificationCenterClient = SystemJourneyNotificationCenter(),
        reminderStore: any ScheduledJourneyReminderStoring = UserDefaultsScheduledJourneyReminderStore(),
        preferencesStore: any JourneyNotificationPreferencesStoring = UserDefaultsJourneyNotificationPreferencesStore(),
        activeJourneyManager: any JourneyNotificationActiveJourneyManaging = NoOpJourneyNotificationActiveJourneyManager(),
        now: @escaping @Sendable () -> Date = { .now }
    ) {
        self.center = center
        self.reminderStore = reminderStore
        self.preferencesStore = preferencesStore
        self.activeJourneyManager = activeJourneyManager
        self.now = now
        preferences = JourneyNotificationPreferences()
    }

    var isAuthorized: Bool {
        authorizationStatus == .authorized ||
            authorizationStatus == .provisional ||
            authorizationStatus == .ephemeral
    }

    var hasScheduledReminder: Bool { reminder != nil }

    func restore() async {
        if let stored = try? await reminderStore.load() {
            reminder = stored
        }
        if let storedPreferences = try? await preferencesStore.load() {
            preferences = storedPreferences
        }
        await refreshAuthorizationStatus()
        await reconcile()
    }

    func refreshAuthorizationStatus() async {
        authorizationStatus = await center.authorizationStatus()
    }

    func requestAuthorization() async {
        await refreshAuthorizationStatus()
        _ = await ensureAuthorization()
        if isAuthorized {
            await reconcile()
        }
    }

    func scheduleReminder(
        for journey: Journey,
        destination: JourneyDestination,
        source: JourneyResult.Source?
    ) async {
        let currentDate = now()
        let events = JourneyNotificationPlanner.events(
            for: journey,
            preferences: preferences,
            now: currentDate,
            destinationName: destination.name
        )
        let candidate = ScheduledJourneyReminder(
            journey: journey,
            destination: destination,
            source: source,
            scheduledAt: currentDate,
            events: events
        )

        await removePendingRequests(for: reminder)
        reminder = candidate
        try? await reminderStore.save(candidate)
        lastError = nil

        await refreshAuthorizationStatus()
        guard await ensureAuthorization() else { return }
        await addRequests(for: candidate)
    }

    func cancelReminder() async {
        await removePendingRequests(for: reminder)
        reminder = nil
        await reminderStore.clear()
        lastError = nil
    }

    func updateDepartureLeadTime(_ leadTime: JourneyNotificationPreferences.DepartureLeadTime) async {
        preferences.departureLeadTime = leadTime
        try? await preferencesStore.save(preferences)
        guard let reminder else { return }
        await scheduleReminder(
            for: reminder.journey,
            destination: reminder.destination,
            source: reminder.source
        )
    }

    func registerActiveJourney(_ journey: Journey) async {
        await activeJourneyManager.registerActiveJourney(journey)
        if reminder?.journey.id == journey.id {
            await cancelReminder()
        }
    }

    func unregisterActiveJourney(_ journey: Journey) async {
        await activeJourneyManager.unregisterActiveJourney(journey)
        if reminder?.journey.id == journey.id {
            await cancelReminder()
        }
    }

    func reminder(for journeyID: JourneyID) -> ScheduledJourneyReminder? {
        guard reminder?.journey.id == journeyID else { return nil }
        return reminder
    }

    private func reconcile() async {
        guard let stored = reminder else { return }
        let events = JourneyNotificationPlanner.events(
            for: stored.journey,
            preferences: preferences,
            now: now(),
            destinationName: stored.destination.name
        )
        guard !events.isEmpty else {
            await cancelReminder()
            return
        }

        let reconciled = ScheduledJourneyReminder(
            journey: stored.journey,
            destination: stored.destination,
            source: stored.source,
            scheduledAt: stored.scheduledAt,
            events: events
        )
        await removePendingRequests(for: stored)
        reminder = reconciled
        try? await reminderStore.save(reconciled)
        guard await ensureAuthorization() else { return }
        await addRequests(for: reconciled)
    }

    private func ensureAuthorization() async -> Bool {
        switch authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            lastError = nil
            return true
        case .notDetermined:
            do {
                _ = try await center.requestAuthorization()
                await refreshAuthorizationStatus()
                guard isAuthorized else {
                    lastError = "Les rappels restent mémorisés. Autorisez les notifications dans Réglages iOS."
                    return false
                }
                return true
            } catch {
                lastError = "Les rappels restent mémorisés, mais les notifications n’ont pas pu être activées."
                return false
            }
        case .denied:
            lastError = "Les rappels restent mémorisés. Autorisez les notifications dans Réglages iOS."
            return false
        @unknown default:
            lastError = "Les rappels restent mémorisés. Vérifiez les autorisations iOS."
            return false
        }
    }

    private func addRequests(for reminder: ScheduledJourneyReminder) async {
        var addedIdentifiers: [String] = []
        do {
            for event in reminder.events {
                let content = UNMutableNotificationContent()
                content.title = event.title
                content.body = event.body
                content.sound = .default
                content.userInfo = event.userInfo.reduce(into: [AnyHashable: Any]()) { result, item in
                    result[item.key] = item.value
                }

                var components = Calendar.autoupdatingCurrent.dateComponents(
                    [.year, .month, .day, .hour, .minute, .second],
                    from: event.date
                )
                components.timeZone = Calendar.autoupdatingCurrent.timeZone
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                try await center.add(
                    UNNotificationRequest(
                        identifier: event.requestIdentifier,
                        content: content,
                        trigger: trigger
                    )
                )
                addedIdentifiers.append(event.requestIdentifier)
            }
        } catch {
            center.removePendingNotificationRequests(withIdentifiers: addedIdentifiers)
            lastError = "Les rappels sont mémorisés et seront réessayés plus tard."
        }
    }

    private func removePendingRequests(for reminder: ScheduledJourneyReminder?) async {
        guard let reminder else { return }
        center.removePendingNotificationRequests(
            withIdentifiers: reminder.events.map(\.requestIdentifier)
        )
    }
}

@MainActor
private final class PreviewJourneyNotificationCenter: JourneyNotificationCenterClient {
    func authorizationStatus() async -> UNAuthorizationStatus { .authorized }
    func requestAuthorization() async throws -> Bool { true }
    func add(_ request: UNNotificationRequest) async throws {}
    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {}
}

actor InMemoryJourneyNotificationPreferencesStore: JourneyNotificationPreferencesStoring {
    private var preferences: JourneyNotificationPreferences?

    func load() -> JourneyNotificationPreferences? { preferences }

    func save(_ preferences: JourneyNotificationPreferences) {
        self.preferences = preferences
    }
}
