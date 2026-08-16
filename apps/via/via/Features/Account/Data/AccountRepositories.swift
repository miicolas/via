import Foundation

protocol FavoriteStationRepository: Sendable {
    func favorites() -> [FavoriteStation]
    func isFavorite(stationID: StationID) -> Bool
    @discardableResult func toggle(stationID: StationID, name: String) -> Bool
    func remove(stationID: String)
}

protocol TransportPreferencesRepository: Sendable {
    func load() -> TransportPreferences
    func store(_ preferences: TransportPreferences)
}

/// The one account-backed repository: every mutation goes through
/// `synchronizing`, so no wrapper can forget to schedule a sync.
final class SyncedAccountRepository: FavoriteStationRepository, TransportPreferencesRepository,
    RecentSearchRepository, @unchecked Sendable {
    private let store: AccountLocalStore
    private let sync: AccountSyncCoordinator

    init(store: AccountLocalStore, sync: AccountSyncCoordinator) {
        self.store = store
        self.sync = sync
    }

    func favorites() -> [FavoriteStation] { store.favorites() }
    func isFavorite(stationID: StationID) -> Bool { store.isFavorite(stationID: stationID) }

    @discardableResult
    func toggle(stationID: StationID, name: String) -> Bool {
        synchronizing { store.toggleFavorite(stationID: stationID, name: name) }
    }

    func remove(stationID: String) {
        synchronizing { store.removeFavorite(stationID: stationID) }
    }

    func load() -> TransportPreferences { store.preferences() }

    func store(_ preferences: TransportPreferences) {
        synchronizing { store.setPreferences(preferences) }
    }

    func load() -> [RecentSearch] { store.recents() }

    func store(_ searches: [RecentSearch]) {
        synchronizing { store.storeRecents(searches) }
    }

    func clear() {
        synchronizing { store.clearRecents() }
    }

    private func synchronizing<Value>(_ mutate: () -> Value) -> Value {
        let value = mutate()
        Task { await sync.synchronize() }
        return value
    }
}
