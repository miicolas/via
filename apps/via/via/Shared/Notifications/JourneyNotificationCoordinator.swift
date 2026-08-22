import Foundation
import Observation
import UserNotifications

@MainActor
protocol JourneyNotificationCenterClient: AnyObject {
    func authorizationStatus() async -> UNAuthorizationStatus
    func requestAuthorization() async throws -> Bool
    func add(_ request: UNNotificationRequest) async throws
    func pendingNotificationRequests() async -> [UNNotificationRequest]
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

    func pendingNotificationRequests() async -> [UNNotificationRequest] {
        await center.pendingNotificationRequests()
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
final class JourneyNotificationCoordinator: JourneyNotificationActiveJourneyManaging {
    static let preview = JourneyNotificationCoordinator(
        center: PreviewJourneyNotificationCenter(),
        reminderStore: InMemoryScheduledJourneyReminderStore(),
        preferencesStore: InMemoryJourneyNotificationPreferencesStore()
    )

    private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    private(set) var reminder: ScheduledJourneyReminder?
    private(set) var isReminderScheduled = false
    private(set) var lastError: String?
    private(set) var preferences: JourneyNotificationPreferences
    private(set) var isUpdatingReminder = false

    @ObservationIgnored private let center: any JourneyNotificationCenterClient
    @ObservationIgnored private let reminderStore: any ScheduledJourneyReminderStoring
    @ObservationIgnored private let preferencesStore: any JourneyNotificationPreferencesStoring
    @ObservationIgnored private let activeJourneyManager: any JourneyNotificationActiveJourneyManaging
    @ObservationIgnored private let now: @Sendable () -> Date
    @ObservationIgnored private var updateWaiters: [CheckedContinuation<Void, Never>] = []

    init(
        center: any JourneyNotificationCenterClient = SystemJourneyNotificationCenter(),
        reminderStore: any ScheduledJourneyReminderStoring = LocalScheduledJourneyReminderStore(),
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

    /// Non-nil only while the system actually holds this reminder's requests;
    /// the id itself is always the stored reminder's.
    var scheduledJourneyID: JourneyID? {
        isReminderScheduled ? reminder?.journey.id : nil
    }

    func restore() async {
        await beginReminderUpdate()
        defer { endReminderUpdate() }
        do {
            reminder = try await reminderStore.load()
            if reminder == nil {
                await removeOrphanedViaRequests()
            }
        } catch {
            await recoverFromUnreadableReminderStore()
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
        await beginReminderUpdate()
        defer { endReminderUpdate() }
        await refreshAuthorizationStatus()
        _ = await ensureAuthorization()
        if isAuthorized {
            await reconcile()
        }
    }

    func sceneBecameActive() async {
        await beginReminderUpdate()
        defer { endReminderUpdate() }
        await refreshAuthorizationStatus()
        await reconcile()
    }

    func scheduleReminder(
        for journey: Journey,
        destination: JourneyDestination,
        source: JourneyResult.Source?,
        planningPolicy: JourneyPlanningPolicy = JourneyPlanningPolicy()
    ) async {
        await beginReminderUpdate()
        defer { endReminderUpdate() }
        await replaceReminder(
            for: journey,
            destination: destination,
            source: source,
            planningPolicy: planningPolicy
        )
    }

    /// Replans every pending event from a revised timetable. The replacement
    /// path saves the new plan before removing old requests and rolls back if
    /// installing the new notifications fails.
    func applyJourneyRevision(_ journey: Journey) async {
        guard let reminder, reminder.journey.id == journey.id else { return }
        await beginReminderUpdate()
        defer { endReminderUpdate() }
        await replaceReminder(
            for: journey,
            destination: reminder.destination,
            source: reminder.source,
            planningPolicy: reminder.planningPolicy
        )
    }

    private func replaceReminder(
        for journey: Journey,
        destination: JourneyDestination,
        source: JourneyResult.Source?,
        planningPolicy: JourneyPlanningPolicy
    ) async {
        let currentDate = now()
        let events = JourneyNotificationPlanner.events(
            for: journey,
            preferences: preferences,
            now: currentDate,
            destinationName: destination.name
        )
        guard !events.isEmpty else {
            lastError = "Ce trajet est terminé et ne peut plus être programmé."
            return
        }
        let candidate = ScheduledJourneyReminder(
            journey: journey,
            destination: destination,
            source: source,
            planningPolicy: planningPolicy,
            scheduledAt: currentDate,
            events: events
        )

        let previous = reminder
        do {
            try await reminderStore.save(candidate)
        } catch {
            lastError = "Le rappel n’a pas pu être enregistré sur cet appareil."
            return
        }
        isReminderScheduled = false
        reminder = candidate
        lastError = nil

        await refreshAuthorizationStatus()
        guard await ensureAuthorization() else {
            await removePendingRequests(for: previous)
            return
        }
        await installRequests(for: candidate, replacing: previous)
    }

    func cancelReminder() async {
        await beginReminderUpdate()
        defer { endReminderUpdate() }
        await clearReminder()
    }

    private func clearReminder() async {
        do {
            try await reminderStore.clear()
        } catch {
            lastError = "Le rappel n’a pas pu être supprimé de cet appareil."
            return
        }
        await removePendingRequests(for: reminder)
        isReminderScheduled = false
        reminder = nil
        lastError = nil
    }

    private func recoverFromUnreadableReminderStore() async {
        await removeOrphanedViaRequests()
        reminder = nil
        isReminderScheduled = false
        do {
            try await reminderStore.clear()
            lastError = "Un rappel illisible a été supprimé de cet appareil."
        } catch {
            lastError = "Un rappel illisible n’a pas pu être supprimé de cet appareil."
        }
    }

    private func removeOrphanedViaRequests() async {
        let orphanedIdentifiers = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix(JourneyNotificationEvent.requestIdentifierPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: orphanedIdentifiers)
    }

    func updateDepartureLeadTime(_ leadTime: JourneyNotificationPreferences.DepartureLeadTime) async {
        await beginReminderUpdate()
        defer { endReminderUpdate() }
        let previousPreferences = preferences
        preferences.departureLeadTime = leadTime
        do {
            try await preferencesStore.save(preferences)
        } catch {
            preferences = previousPreferences
            lastError = "La préférence de rappel n’a pas pu être enregistrée."
            return
        }
        guard let reminder else { return }
        await replaceReminder(
            for: reminder.journey,
            destination: reminder.destination,
            source: reminder.source,
            planningPolicy: reminder.planningPolicy
        )
    }

    func registerActiveJourney(_ journey: Journey) async {
        await beginReminderUpdate()
        defer { endReminderUpdate() }
        await refreshAuthorizationStatus()
        if authorizationStatus == .notDetermined {
            _ = await ensureAuthorization()
        }
        await activeJourneyManager.registerActiveJourney(journey)
        if reminder?.journey.id == journey.id {
            await clearReminder()
        }
    }

    func unregisterActiveJourney(_ journey: Journey) async {
        await beginReminderUpdate()
        defer { endReminderUpdate() }
        await activeJourneyManager.unregisterActiveJourney(journey)
        if reminder?.journey.id == journey.id {
            await clearReminder()
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
            await removePendingRequests(for: stored)
            isReminderScheduled = false
            if now() > stored.journey.arrivalAt.addingTimeInterval(24 * 60 * 60) {
                await clearReminder()
            }
            return
        }

        // Every foreground reconciles. Re-saving and re-adding identical
        // requests would cost a file write and one XPC round trip per event.
        guard events != stored.events || !isReminderScheduled else { return }

        let reconciled = ScheduledJourneyReminder(
            journey: stored.journey,
            destination: stored.destination,
            source: stored.source,
            planningPolicy: stored.planningPolicy,
            scheduledAt: stored.scheduledAt,
            events: events
        )
        do {
            try await reminderStore.save(reconciled)
        } catch {
            lastError = "Le rappel n’a pas pu être mis à jour sur cet appareil."
            return
        }
        isReminderScheduled = false
        reminder = reconciled
        guard await ensureAuthorization() else { return }
        await installRequests(for: reconciled, replacing: stored)
    }

    /// The rollback protocol both write paths share: on failure the previous
    /// reminder and its pending requests are put back exactly as they were.
    private func installRequests(
        for candidate: ScheduledJourneyReminder,
        replacing previous: ScheduledJourneyReminder?
    ) async {
        let update = await addRequests(for: candidate, restoring: previous)
        guard update.scheduled else {
            await restoreReminderAfterSchedulingFailure(
                previous,
                requestsRestored: update.restoredPrevious
            )
            return
        }
        removeObsoletePendingRequests(previous: previous, current: candidate)
        isReminderScheduled = true
    }

    private func ensureAuthorization() async -> Bool {
        switch authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            lastError = nil
            return true
        case .notDetermined:
            // Through the shared seam so the grant registers the APNs token on
            // the same turn rather than on the next foreground.
            let granted = await NotificationAuthorization.request(center: center)
            await refreshAuthorizationStatus()
            guard granted, isAuthorized else {
                lastError = "Les rappels restent mémorisés. Autorisez les notifications dans Réglages iOS."
                return false
            }
            lastError = nil
            return true
        case .denied:
            lastError = "Les rappels restent mémorisés. Autorisez les notifications dans Réglages iOS."
            return false
        @unknown default:
            lastError = "Les rappels restent mémorisés. Vérifiez les autorisations iOS."
            return false
        }
    }

    private func addRequests(
        for reminder: ScheduledJourneyReminder,
        restoring previous: ScheduledJourneyReminder?
    ) async -> (scheduled: Bool, restoredPrevious: Bool) {
        var addedIdentifiers: [String] = []
        do {
            for event in reminder.events {
                try await center.add(notificationRequest(for: event))
                addedIdentifiers.append(event.requestIdentifier)
            }
            lastError = nil
            return (true, false)
        } catch {
            center.removePendingNotificationRequests(withIdentifiers: addedIdentifiers)
            var restoredPrevious = previous != nil
            if let previous {
                for event in previous.events {
                    do {
                        try await center.add(notificationRequest(for: event))
                    } catch {
                        restoredPrevious = false
                    }
                }
            }
            lastError = "Les rappels sont mémorisés et seront réessayés plus tard."
            return (false, restoredPrevious)
        }
    }

    private func restoreReminderAfterSchedulingFailure(
        _ previous: ScheduledJourneyReminder?,
        requestsRestored: Bool
    ) async {
        if let previous {
            reminder = previous
            do {
                try await reminderStore.save(previous)
                isReminderScheduled = requestsRestored
            } catch {
                isReminderScheduled = false
                lastError = "Le rappel précédent n’a pas pu être restauré sur cet appareil."
            }
        } else {
            isReminderScheduled = false
        }
    }

    private func notificationRequest(
        for event: JourneyNotificationEvent
    ) -> UNNotificationRequest {
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
        return UNNotificationRequest(
            identifier: event.requestIdentifier,
            content: content,
            trigger: trigger
        )
    }

    private func removePendingRequests(for reminder: ScheduledJourneyReminder?) async {
        guard let reminder else { return }
        center.removePendingNotificationRequests(
            withIdentifiers: reminder.events.map(\.requestIdentifier)
        )
    }

    private func removeObsoletePendingRequests(
        previous: ScheduledJourneyReminder?,
        current: ScheduledJourneyReminder
    ) {
        guard let previous else { return }
        let currentIdentifiers = Set(current.events.map(\.requestIdentifier))
        let obsolete = previous.events
            .map(\.requestIdentifier)
            .filter { !currentIdentifiers.contains($0) }
        center.removePendingNotificationRequests(withIdentifiers: obsolete)
    }

    private func beginReminderUpdate() async {
        if isUpdatingReminder {
            await withCheckedContinuation { continuation in
                updateWaiters.append(continuation)
            }
            return
        }
        isUpdatingReminder = true
    }

    private func endReminderUpdate() {
        if updateWaiters.isEmpty {
            isUpdatingReminder = false
        } else {
            updateWaiters.removeFirst().resume()
        }
    }
}

@MainActor
private final class PreviewJourneyNotificationCenter: JourneyNotificationCenterClient {
    func authorizationStatus() async -> UNAuthorizationStatus { .authorized }
    func requestAuthorization() async throws -> Bool { true }
    func add(_ request: UNNotificationRequest) async throws {}
    func pendingNotificationRequests() async -> [UNNotificationRequest] { [] }
    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {}
}

actor InMemoryJourneyNotificationPreferencesStore: JourneyNotificationPreferencesStoring {
    private var preferences: JourneyNotificationPreferences?

    func load() -> JourneyNotificationPreferences? { preferences }

    func save(_ preferences: JourneyNotificationPreferences) {
        self.preferences = preferences
    }
}
