import Foundation

protocol ScheduledJourneyReminderStoring: Sendable {
    func load() throws -> ScheduledJourneyReminder?
    func save(_ reminder: ScheduledJourneyReminder) throws
    func clear()
}

actor UserDefaultsScheduledJourneyReminderStore: ScheduledJourneyReminderStoring {
    private let defaults: UserDefaults
    private let key: String
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(
        defaults: UserDefaults = .standard,
        key: String = "via.journey-notification.reminder.v1"
    ) {
        self.defaults = defaults
        self.key = key
    }

    func load() throws -> ScheduledJourneyReminder? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try decoder.decode(ScheduledJourneyReminder.self, from: data)
    }

    func save(_ reminder: ScheduledJourneyReminder) throws {
        defaults.set(try encoder.encode(reminder), forKey: key)
    }

    func clear() {
        defaults.removeObject(forKey: key)
    }
}

actor InMemoryScheduledJourneyReminderStore: ScheduledJourneyReminderStoring {
    private var reminder: ScheduledJourneyReminder?

    init(reminder: ScheduledJourneyReminder? = nil) {
        self.reminder = reminder
    }

    func load() -> ScheduledJourneyReminder? { reminder }

    func save(_ reminder: ScheduledJourneyReminder) {
        self.reminder = reminder
    }

    func clear() {
        reminder = nil
    }
}

protocol JourneyNotificationPreferencesStoring: Sendable {
    func load() throws -> JourneyNotificationPreferences?
    func save(_ preferences: JourneyNotificationPreferences) throws
}

actor UserDefaultsJourneyNotificationPreferencesStore: JourneyNotificationPreferencesStoring {
    private let defaults: UserDefaults
    private let key: String
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(
        defaults: UserDefaults = .standard,
        key: String = "via.journey-notification.preferences.v1"
    ) {
        self.defaults = defaults
        self.key = key
    }

    func load() throws -> JourneyNotificationPreferences? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try decoder.decode(JourneyNotificationPreferences.self, from: data)
    }

    func save(_ preferences: JourneyNotificationPreferences) throws {
        defaults.set(try encoder.encode(preferences), forKey: key)
    }
}

