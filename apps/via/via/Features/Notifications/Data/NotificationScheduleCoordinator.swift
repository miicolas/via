import Foundation
import Observation
import UserNotifications

@MainActor
@Observable
final class NotificationScheduleCoordinator {
    static let shared = NotificationScheduleCoordinator()

    private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    private(set) var lastError: String?
    private(set) var isReconciling = false

    private let center: UNUserNotificationCenter
    private let defaults: UserDefaults
    private let now: @Sendable () -> Date

    init(
        center: UNUserNotificationCenter = .current(),
        defaults: UserDefaults = .standard,
        now: @escaping @Sendable () -> Date = { .now }
    ) {
        self.center = center
        self.defaults = defaults
        self.now = now
    }

    var isAuthorized: Bool {
        switch authorizationStatus {
        case .authorized, .provisional, .ephemeral: true
        default: false
        }
    }

    func restore() async {
        authorizationStatus = await center.notificationSettings().authorizationStatus
    }

    func requestAuthorization() async {
        do {
            _ = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            await restore()
        } catch {
            lastError = "Les notifications n’ont pas pu être activées."
        }
    }

    /// A notification action can opt one local schedule out immediately. The
    /// schedule remains editable in Via; saving it clears this local mute.
    func mute(scheduleID: String) {
        var muted = Set(defaults.stringArray(forKey: Self.mutedSchedulesKey) ?? [])
        muted.insert(scheduleID)
        defaults.set(Array(muted), forKey: Self.mutedSchedulesKey)
        Task { @MainActor [center] in
            center.removePendingNotificationRequests(
                withIdentifiers: await identifiers(for: scheduleID)
            )
        }
    }

    func unmute(scheduleID: String) {
        var muted = Set(defaults.stringArray(forKey: Self.mutedSchedulesKey) ?? [])
        muted.remove(scheduleID)
        defaults.set(Array(muted), forKey: Self.mutedSchedulesKey)
    }

    /// Keeps at most three upcoming local reminders per commute schedule. A
    /// calendar trigger is based on wall-clock components, so iOS owns DST and
    /// timezone transitions instead of a server timestamp.
    func reconcile(
        schedules: [NotificationSchedule],
        preferences: NotificationPreferences,
        now: Date? = nil
    ) async {
        isReconciling = true
        defer { isReconciling = false }
        await restore()
        let identifiers = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix(Self.requestPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        guard isAuthorized else {
            lastError = authorizationStatus == .denied
                ? "Les programmations restent mémorisées. Autorisez les notifications dans Réglages iOS."
                : nil
            return
        }
        guard preferences.enabled,
              preferences.categories.first(where: { $0.category == .commute })?.enabled ?? true else {
            return
        }

        let reference = now ?? self.now()
        let events = schedules
            .filter {
                $0.kind == .commute &&
                    $0.enabled &&
                    $0.deletedAt == nil &&
                    !isMuted(scheduleID: $0.id)
            }
            .flatMap { schedule in
                upcomingEvents(for: schedule, preferences: preferences, after: reference)
            }
            .prefix(60)

        do {
            for event in events {
                try await center.add(request(for: event))
            }
            lastError = nil
        } catch {
            lastError = "Les rappels sont mémorisés et seront réessayés plus tard."
        }
    }

    private func request(for event: LocalNotificationEvent) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = event.title
        content.body = event.body
        content.sound = .default
        content.threadIdentifier = "via.notification.commute.\(event.scheduleID)"
        content.categoryIdentifier = "via.notification.commute"
        content.userInfo = [
            "type": "notification",
            "category": NotificationCategory.commute.rawValue,
            "scheduleId": event.scheduleID,
            "deepLink": "via://notifications",
            "url": "via://notifications"
        ]
        var components = Calendar.autoupdatingCurrent.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: event.date
        )
        components.timeZone = Calendar.autoupdatingCurrent.timeZone
        return UNNotificationRequest(
            identifier: event.identifier,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        )
    }

    private func upcomingEvents(
        for schedule: NotificationSchedule,
        preferences: NotificationPreferences,
        after reference: Date
    ) -> [LocalNotificationEvent] {
        let calendar = Calendar.autoupdatingCurrent
        let startDay = calendar.startOfDay(for: reference)
        var events: [LocalNotificationEvent] = []
        for offset in 0..<42 where events.count < 3 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: startDay) else { continue }
            let weekday = calendar.component(.weekday, from: day) - 1
            guard schedule.daysOfWeek.contains(weekday) else { continue }
            if schedule.skipHolidays && Self.isFrenchHoliday(day, calendar: calendar) { continue }
            var departure = calendar.date(byAdding: .minute, value: schedule.departureMinute, to: day) ?? day
            departure = calendar.date(byAdding: .minute, value: -schedule.leadMinutes, to: departure) ?? departure
            guard departure > reference, !Self.isQuiet(departure, preferences: preferences, calendar: calendar) else { continue }
            let minute = calendar.component(.minute, from: departure)
            let dateKey = Self.dateFormatter.string(from: departure)
            events.append(LocalNotificationEvent(
                scheduleID: schedule.id,
                identifier: "\(Self.requestPrefix)\(schedule.id).\(dateKey).\(minute)",
                date: departure,
                title: "Départ dans \(schedule.leadMinutes) minutes",
                body: "\(schedule.label) commence bientôt."
            ))
        }
        return events
    }

    private static let requestPrefix = "via.schedule."
    private static let mutedSchedulesKey = "via.notification.muted-schedules"
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .autoupdatingCurrent
        formatter.dateFormat = "yyyyMMdd"
        return formatter
    }()

    private static func isQuiet(
        _ date: Date,
        preferences: NotificationPreferences,
        calendar: Calendar
    ) -> Bool {
        let weekday = calendar.component(.weekday, from: date)
        if preferences.mutedOnWeekends && (weekday == 1 || weekday == 7) { return true }
        if preferences.mutedOnHolidays && isFrenchHoliday(date, calendar: calendar) { return true }
        let minute = calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
        guard let start = preferences.quietHoursStartMinute,
              let end = preferences.quietHoursEndMinute else { return false }
        return start < end ? minute >= start && minute < end : minute >= start || minute < end
    }

    private func isMuted(scheduleID: String) -> Bool {
        defaults.stringArray(forKey: Self.mutedSchedulesKey)?.contains(scheduleID) == true
    }

    private func identifiers(for scheduleID: String) async -> [String] {
        await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix("\(Self.requestPrefix)\(scheduleID).") }
    }

    private static func isFrenchHoliday(_ date: Date, calendar: Calendar) -> Bool {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        guard let year = components.year, let month = components.month, let day = components.day else { return false }
        if [(1, 1), (5, 1), (5, 8), (7, 14), (8, 15), (11, 1), (11, 11), (12, 25)].contains(where: { $0 == (month, day) }) {
            return true
        }
        // The local schedule needs only the movable French holidays. Easter
        // Sunday is computed with the Gregorian Meeus algorithm.
        let easter = easterSunday(year: year, calendar: calendar)
        return [1, 39, 50].contains { offset in
            calendar.date(byAdding: .day, value: offset, to: easter).map { calendar.isDate($0, inSameDayAs: date) } ?? false
        }
    }

    private static func easterSunday(year: Int, calendar: Calendar) -> Date {
        let a = year % 19
        let b = year / 100
        let c = year % 100
        let d = b / 4
        let e = b % 4
        let f = (b + 8) / 25
        let g = (b - f + 1) / 3
        let h = (19 * a + b - d - g + 15) % 30
        let i = c / 4
        let k = c % 4
        let l = (32 + 2 * e + 2 * i - h - k) % 7
        let m = (a + 11 * h + 22 * l) / 451
        let month = (h + l - 7 * m + 114) / 31
        let day = ((h + l - 7 * m + 114) % 31) + 1
        return calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? .distantPast
    }
}

private struct LocalNotificationEvent {
    let scheduleID: String
    let identifier: String
    let date: Date
    let title: String
    let body: String
}
