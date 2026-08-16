import Foundation

protocol RecentSearchRepository: Sendable {
    func load() -> [RecentSearch]
    func store(_ searches: [RecentSearch])
    func clear()
}

final class UserDefaultsRecentSearchRepository: RecentSearchRepository, @unchecked Sendable {
    private let defaults: UserDefaults
    private let key = "via.recent-searches.v1"
    private var cached: [RecentSearch]?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> [RecentSearch] {
        if let cached { return cached }
        let values = defaults.data(forKey: key)
            .flatMap { try? JSONDecoder.via.decode([RecentSearch].self, from: $0) } ?? []
        cached = values
        return values
    }

    func store(_ searches: [RecentSearch]) {
        cached = searches
        guard let data = try? JSONEncoder.via.encode(searches) else { return }
        defaults.set(data, forKey: key)
    }

    func clear() {
        cached = []
        defaults.removeObject(forKey: key)
    }
}

final class InMemoryRecentSearchRepository: RecentSearchRepository, @unchecked Sendable {
    private var values: [RecentSearch]

    init(values: [RecentSearch] = []) { self.values = values }

    func load() -> [RecentSearch] { values }

    func store(_ searches: [RecentSearch]) { values = searches }

    func clear() { values = [] }
}
