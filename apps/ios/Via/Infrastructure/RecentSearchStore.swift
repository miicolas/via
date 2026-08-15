import Foundation

protocol RecentSearchStore {
    func load() -> [SearchResult]
    func save(_ entries: [SearchResult])
}

struct UserDefaultsRecentSearchStore: RecentSearchStore {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> [SearchResult] {
        parseRecentSearches(defaults.data(forKey: RecentSearchStorage.key))
    }

    func save(_ entries: [SearchResult]) {
        guard let data = serializeRecentSearches(entries) else { return }
        defaults.set(data, forKey: RecentSearchStorage.key)
    }
}

final class InMemoryRecentSearchStore: RecentSearchStore {
    private(set) var entries: [SearchResult]

    init(entries: [SearchResult] = []) {
        self.entries = entries
    }

    func load() -> [SearchResult] {
        entries
    }

    func save(_ entries: [SearchResult]) {
        self.entries = entries
    }
}
