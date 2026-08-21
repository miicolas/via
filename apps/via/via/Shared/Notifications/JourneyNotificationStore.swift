import Foundation

protocol ScheduledJourneyReminderStoring: Sendable {
    func load() throws -> ScheduledJourneyReminder?
    func save(_ reminder: ScheduledJourneyReminder) throws
    func clear() throws
}

actor LocalScheduledJourneyReminderStore: ScheduledJourneyReminderStoring {
    private let file: LocalJSONFile

    init(fileURL: URL? = nil) {
        file = fileURL.map(LocalJSONFile.init(url:))
            ?? LocalJSONFile(name: "journey-notification-reminder.json")
    }

    func load() throws -> ScheduledJourneyReminder? {
        guard let data = try file.read() else { return nil }
        return try JSONDecoder.via.decode(ScheduledJourneyReminder.self, from: data)
    }

    func save(_ reminder: ScheduledJourneyReminder) throws {
        try file.write(try JSONEncoder.via.encode(reminder))
    }

    func clear() throws {
        try file.remove()
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

    init(
        defaults: UserDefaults = .standard,
        key: String = "via.journey-notification.preferences.v1"
    ) {
        self.defaults = defaults
        self.key = key
    }

    func load() throws -> JourneyNotificationPreferences? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try JSONDecoder.via.decode(JourneyNotificationPreferences.self, from: data)
    }

    func save(_ preferences: JourneyNotificationPreferences) throws {
        defaults.set(try JSONEncoder.via.encode(preferences), forKey: key)
    }
}
