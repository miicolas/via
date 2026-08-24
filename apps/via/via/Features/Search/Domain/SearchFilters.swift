import Foundation

struct SearchFilters: Codable, Sendable, Hashable {
    var requiresAccessibleStations = false
    var requiresOperationalElevators = false
    var bikeStationsOnly = false

    var activeCount: Int {
        (requiresAccessibleStations ? 1 : 0)
            + (requiresOperationalElevators ? 1 : 0)
            + (bikeStationsOnly ? 1 : 0)
    }

    private enum CodingKeys: String, CodingKey {
        case requiresAccessibleStations
        case requiresOperationalElevators
        case bikeStationsOnly
    }

    init(
        requiresAccessibleStations: Bool = false,
        requiresOperationalElevators: Bool = false,
        bikeStationsOnly: Bool = false
    ) {
        self.requiresAccessibleStations = requiresAccessibleStations
        self.requiresOperationalElevators = requiresOperationalElevators
        self.bikeStationsOnly = bikeStationsOnly
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        requiresAccessibleStations = try values.decodeIfPresent(
            Bool.self,
            forKey: .requiresAccessibleStations
        ) ?? false
        requiresOperationalElevators = try values.decodeIfPresent(
            Bool.self,
            forKey: .requiresOperationalElevators
        ) ?? false
        bikeStationsOnly = try values.decodeIfPresent(
            Bool.self,
            forKey: .bikeStationsOnly
        ) ?? false
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
