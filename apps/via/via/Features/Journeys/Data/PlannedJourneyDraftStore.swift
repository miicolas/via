import Foundation

protocol PlannedJourneyDraftStoring: Sendable {
    func load() async throws -> PlannedJourneyDraft?
    func save(_ draft: PlannedJourneyDraft) async throws
    func clear() async
}

actor UserDefaultsPlannedJourneyDraftStore: PlannedJourneyDraftStoring {
    private let defaults: UserDefaults
    private let key: String

    init(
        defaults: UserDefaults = .standard,
        key: String = "via.planned-journey-draft.v1"
    ) {
        self.defaults = defaults
        self.key = key
    }

    func load() throws -> PlannedJourneyDraft? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try JSONDecoder.via.decode(PlannedJourneyDraft.self, from: data)
    }

    func save(_ draft: PlannedJourneyDraft) throws {
        defaults.set(try JSONEncoder.via.encode(draft), forKey: key)
    }

    func clear() {
        defaults.removeObject(forKey: key)
    }
}

actor InMemoryPlannedJourneyDraftStore: PlannedJourneyDraftStoring {
    private var draft: PlannedJourneyDraft?

    init(draft: PlannedJourneyDraft? = nil) {
        self.draft = draft
    }

    func load() -> PlannedJourneyDraft? { draft }

    func save(_ draft: PlannedJourneyDraft) {
        self.draft = draft
    }

    func clear() {
        draft = nil
    }
}
