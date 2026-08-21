import Foundation

protocol RecentSearchStoring: Sendable {
    func load() -> [RecentSearch]
    func upsert(_ recent: RecentSearch) -> [RecentSearch]
    func remove(id: String) -> [RecentSearch]
    func clear() -> [RecentSearch]
}

struct UserDefaultsRecentSearchStore: RecentSearchStoring, @unchecked Sendable {
    private static let storageKey = "via.local-recent-searches.v1"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> [RecentSearch] {
        guard
            let data = defaults.data(forKey: Self.storageKey),
            let searches = try? JSONDecoder.via.decode([RecentSearch].self, from: data)
        else {
            return []
        }
        return RecentSearch.normalizedHistory(searches)
    }

    func upsert(_ recent: RecentSearch) -> [RecentSearch] {
        let searches = RecentSearch.normalizedHistory(load() + [recent])
        save(searches)
        return searches
    }

    func remove(id: String) -> [RecentSearch] {
        let searches = load().filter { $0.id != id }
        save(searches)
        return searches
    }

    func clear() -> [RecentSearch] {
        defaults.removeObject(forKey: Self.storageKey)
        return []
    }

    private func save(_ searches: [RecentSearch]) {
        guard let data = try? JSONEncoder.via.encode(searches) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }
}

final class InMemoryRecentSearchStore: RecentSearchStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var searches: [RecentSearch]

    init(searches: [RecentSearch] = []) {
        self.searches = RecentSearch.normalizedHistory(searches)
    }

    func load() -> [RecentSearch] {
        lock.withLock { searches }
    }

    func upsert(_ recent: RecentSearch) -> [RecentSearch] {
        lock.withLock {
            searches = RecentSearch.normalizedHistory(searches + [recent])
            return searches
        }
    }

    func remove(id: String) -> [RecentSearch] {
        lock.withLock {
            searches.removeAll { $0.id == id }
            return searches
        }
    }

    func clear() -> [RecentSearch] {
        lock.withLock {
            searches = []
            return []
        }
    }
}
