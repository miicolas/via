import Foundation
import Observation

@MainActor
@Observable
final class AccountModel {
    private(set) var state: AccountState = .inactive

    @ObservationIgnored private let store: AccountLocalStore
    @ObservationIgnored private let remote: any AccountRemote
    @ObservationIgnored private let synchronizationEnabled: Bool
    @ObservationIgnored private let now: @Sendable () -> Date
    @ObservationIgnored private var activeUserID: String?
    @ObservationIgnored private var synchronizationTask: Task<Void, Never>?

    init(
        store: AccountLocalStore = AccountLocalStore(),
        remote: any AccountRemote,
        synchronizationEnabled: Bool = true,
        now: @escaping @Sendable () -> Date = { .now }
    ) {
        self.store = store
        self.remote = remote
        self.synchronizationEnabled = synchronizationEnabled
        self.now = now
    }

    var snapshot: AccountSnapshot {
        guard case .active(let snapshot, _) = state else { return .empty }
        return snapshot
    }

    var syncState: AccountSyncState {
        guard case .active(_, let syncState) = state else { return .local }
        return syncState
    }

    var favorites: [FavoriteStation] { snapshot.favorites }
    var recentSearches: [RecentSearch] { snapshot.recentSearches }
    var transportPreferences: TransportPreferences { snapshot.transportPreferences }

    func activate(userID: String) {
        synchronizationTask?.cancel()
        synchronizationTask = nil
        activeUserID = userID
        store.activate(userID: userID)
        refresh(syncState: .local)
        scheduleSynchronization(fetchCanonical: true)
    }

    func deactivate() {
        synchronizationTask?.cancel()
        synchronizationTask = nil
        activeUserID = nil
        store.deactivate()
        state = .inactive
    }

    @discardableResult
    func toggleFavorite(stationID: StationID, name: String) -> Bool {
        let isFavorite = store.toggleFavorite(stationID: stationID, name: name, now: now())
        refresh(syncState: syncState)
        scheduleSynchronization()
        return isFavorite
    }

    func removeFavorite(stationID: String) {
        store.removeFavorite(stationID: stationID, now: now())
        refresh(syncState: syncState)
        scheduleSynchronization()
    }

    func isFavorite(stationID: StationID) -> Bool {
        snapshot.favorites.contains { $0.stationID == stationID.rawValue }
    }

    func recordRecentSearch(_ result: SearchResult) {
        let recent = RecentSearch(result: result, savedAt: now())
        let history = [recent] + recentSearches.filter { $0.id != recent.id }
        store.storeRecents(Array(history.prefix(AccountLocalSnapshot.recentLimit)))
        refresh(syncState: syncState)
        scheduleSynchronization()
    }

    func clearRecentSearches() {
        store.clearRecents(now: now())
        refresh(syncState: syncState)
        scheduleSynchronization()
    }

    func setPreferred(_ mode: TransitMode, enabled: Bool) {
        var preferences = transportPreferences
        if enabled {
            preferences.preferredModes.insert(mode)
            preferences.excludedModes.remove(mode)
        } else {
            preferences.preferredModes.remove(mode)
        }
        preferences.updatedAt = now()
        store.setPreferences(preferences)
        refresh(syncState: syncState)
        scheduleSynchronization()
    }

    func resumeSynchronization() {
        scheduleSynchronization(fetchCanonical: true)
    }

    func retrySynchronization() {
        scheduleSynchronization(fetchCanonical: true)
    }

    func delete(using proof: AccountDeletionProof) async throws {
        guard let userID = activeUserID else { return }
        try await remote.delete(using: proof)
        guard activeUserID == userID else { return }
        synchronizationTask?.cancel()
        synchronizationTask = nil
        store.erase(userID: userID)
        activeUserID = nil
        state = .inactive
    }

    private func scheduleSynchronization(fetchCanonical: Bool = false) {
        guard synchronizationEnabled, activeUserID != nil else {
            refresh(syncState: .local)
            return
        }
        guard synchronizationTask == nil else { return }
        let expectedUserID = activeUserID
        refresh(syncState: .syncing)
        synchronizationTask = Task { [weak self] in
            guard let self, let expectedUserID else { return }
            await self.synchronize(userID: expectedUserID, fetchCanonical: fetchCanonical)
        }
    }

    private func synchronize(userID: String, fetchCanonical: Bool) async {
        var shouldFetchCanonical = fetchCanonical
        var lastSyncedAt: Date?
        defer { synchronizationTask = nil }

        do {
            while !Task.isCancelled {
                guard
                    activeUserID == userID,
                    let pending = store.pendingSync(),
                    pending.userID == userID
                else { return }

                if pending.operations.isEmpty, !shouldFetchCanonical { break }
                let result = try await remote.synchronize(pending.operations)
                try Task.checkCancellation()
                guard
                    activeUserID == userID,
                    store.pendingSync()?.userID == userID
                else { return }

                store.apply(result)
                lastSyncedAt = result.syncedAt
                shouldFetchCanonical = false
                refresh(syncState: .syncing)
            }

            guard activeUserID == userID else { return }
            refresh(syncState: .synced(lastSyncedAt ?? now()))
        } catch is CancellationError {
        } catch {
            guard activeUserID == userID else { return }
            let value = error.via
            switch value {
            case .transport, .unavailable:
                refresh(syncState: .pendingOffline)
            default:
                refresh(syncState: .failed(value))
            }
        }
    }

    private func refresh(syncState: AccountSyncState) {
        guard activeUserID != nil else {
            state = .inactive
            return
        }
        state = .active(
            AccountSnapshot(
                favorites: store.favorites(),
                recentSearches: store.recents(),
                transportPreferences: store.preferences()
            ),
            syncState
        )
    }
}
