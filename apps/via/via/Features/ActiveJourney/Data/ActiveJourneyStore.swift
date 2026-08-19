import Foundation

protocol ActiveJourneyStore: Sendable {
    func load() async throws -> ActiveJourneySession?
    func save(_ session: ActiveJourneySession) async throws
    func clear() async
}

actor UserDefaultsActiveJourneyStore: ActiveJourneyStore {
    private let defaults: UserDefaults
    private let key: String
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(
        defaults: UserDefaults = .standard,
        key: String = "active-journey-session-v1"
    ) {
        self.defaults = defaults
        self.key = key
    }

    func load() throws -> ActiveJourneySession? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try decoder.decode(ActiveJourneySession.self, from: data)
    }

    func save(_ session: ActiveJourneySession) throws {
        defaults.set(try encoder.encode(session), forKey: key)
    }

    func clear() {
        defaults.removeObject(forKey: key)
    }
}

actor InMemoryActiveJourneyStore: ActiveJourneyStore {
    private var session: ActiveJourneySession?

    init(session: ActiveJourneySession? = nil) {
        self.session = session
    }

    func load() -> ActiveJourneySession? { session }

    func save(_ session: ActiveJourneySession) {
        self.session = session
    }

    func clear() {
        session = nil
    }
}
