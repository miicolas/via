import Foundation

protocol RecentSearchStore {
    func load() -> [SearchResult]
    func save(_ entries: [SearchResult])
}

protocol LegacyRecentSearchImporting {
    func load() -> [SearchResult]
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

struct MigratingRecentSearchStore: RecentSearchStore {
    private let current: any RecentSearchStore
    private let legacy: any LegacyRecentSearchImporting
    private let defaults: UserDefaults

    init(
        current: any RecentSearchStore = UserDefaultsRecentSearchStore(),
        legacy: any LegacyRecentSearchImporting = ExpoLegacyRecentSearchImporter(),
        defaults: UserDefaults = .standard
    ) {
        self.current = current
        self.legacy = legacy
        self.defaults = defaults
    }

    func load() -> [SearchResult] {
        let entries = current.load()
        guard !defaults.bool(forKey: RecentSearchStorage.expoMigrationKey) else {
            return entries
        }

        defaults.set(true, forKey: RecentSearchStorage.expoMigrationKey)
        guard entries.isEmpty else { return entries }

        let imported = legacy.load()
        guard !imported.isEmpty else { return entries }
        current.save(imported)
        return current.load()
    }

    func save(_ entries: [SearchResult]) {
        current.save(entries)
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
