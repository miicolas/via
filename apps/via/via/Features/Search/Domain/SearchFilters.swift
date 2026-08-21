import Foundation

struct SearchFilters: Codable, Sendable, Hashable {
    var requiresAccessibleStations = false

    var activeCount: Int {
        requiresAccessibleStations ? 1 : 0
    }
}

protocol SearchFilterStoring: Sendable {
    func load() -> SearchFilters
    func save(_ filters: SearchFilters)
}

struct UserDefaultsSearchFilterStore: SearchFilterStoring, @unchecked Sendable {
    private let defaults: UserDefaults
    private let key = "via.search.filters.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> SearchFilters {
        guard
            let data = defaults.data(forKey: key),
            let filters = try? JSONDecoder().decode(SearchFilters.self, from: data)
        else { return SearchFilters() }
        return filters
    }

    func save(_ filters: SearchFilters) {
        guard let data = try? JSONEncoder().encode(filters) else { return }
        defaults.set(data, forKey: key)
    }
}

final class InMemorySearchFilterStore: SearchFilterStoring, @unchecked Sendable {
    var filters = SearchFilters()

    func load() -> SearchFilters { filters }
    func save(_ filters: SearchFilters) { self.filters = filters }
}
