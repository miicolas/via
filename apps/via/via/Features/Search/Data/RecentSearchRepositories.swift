import Foundation

protocol RecentSearchRepository: Sendable {
    func load() -> [RecentSearch]
    func store(_ searches: [RecentSearch])
    func clear()
}

final class InMemoryRecentSearchRepository: RecentSearchRepository, @unchecked Sendable {
    private var values: [RecentSearch]

    init(values: [RecentSearch] = []) { self.values = values }

    func load() -> [RecentSearch] { values }

    func store(_ searches: [RecentSearch]) { values = searches }

    func clear() { values = [] }
}
