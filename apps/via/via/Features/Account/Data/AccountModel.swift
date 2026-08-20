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
    @ObservationIgnored private var activeScope: AccountScope?
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
        switch state {
        case .inactive:
            return .empty
        case .local(let snapshot), .active(let snapshot, _):
            return snapshot
        }
    }

    var syncState: AccountSyncState {
        switch state {
        case .inactive, .local:
            return .local
        case .active(_, let syncState):
            return syncState
        }
    }

    var isAnonymous: Bool { activeScope == .anonymous }
    var favorites: [FavoriteStation] { snapshot.favorites }
    var recentSearches: [RecentSearch] { snapshot.recentSearches }
    var places: [SavedPlace] { snapshot.places }
    var transportPreferences: TransportPreferences { snapshot.transportPreferences }

    func activateAnonymous() {
        synchronizationTask?.cancel()
        synchronizationTask = nil
        activeScope = .anonymous
        store.activateAnonymous()
        refresh(syncState: .local)
    }

    func activate(userID: String) {
        synchronizationTask?.cancel()
        synchronizationTask = nil
        activeScope = .user(userID)
        store.activate(userID: userID)
        store.mergeAnonymous(into: userID)
        refresh(syncState: .local)
        scheduleSynchronization(fetchCanonical: true)
    }

    /// Leaves the account model without an active workspace. Authentication
    /// uses `activateAnonymous()` after a normal sign-out so the local guest
    /// workspace remains immediately available.
    func deactivate() {
        synchronizationTask?.cancel()
        synchronizationTask = nil
        activeScope = nil
        store.deactivate()
        state = .inactive
    }

    /// Removes every Via account workspace on this device and starts a fresh
    /// anonymous workspace. The remote account is never touched here.
    func eraseDeviceData() {
        synchronizationTask?.cancel()
        synchronizationTask = nil
        store.eraseAll()
        activeScope = nil
        store.deactivate()
        activateAnonymous()
    }

    @discardableResult
    func toggleFavorite(stationID: StationID, name: String, coordinate: GeoCoordinate? = nil) -> Bool {
        let isFavorite = store.toggleFavorite(
            stationID: stationID,
            name: name,
            coordinate: coordinate,
            now: now()
        )
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

    func place(for role: SavedPlace.Role) -> SavedPlace? {
        snapshot.places.first { $0.role == role }
    }

    func setPlace(_ result: SearchResult, role: SavedPlace.Role) {
        store.savePlace(SavedPlace(result: result, role: role, savedAt: now()))
        refresh(syncState: syncState)
        scheduleSynchronization()
    }

    func removePlace(id: String) {
        store.removePlace(id: id, now: now())
        refresh(syncState: syncState)
        scheduleSynchronization()
    }

    func recordRecentSearch(_ result: SearchResult) {
        store.upsertRecent(RecentSearch(result: result, savedAt: now()))
        refresh(syncState: syncState)
        scheduleSynchronization()
    }

    func clearRecentSearches() {
        store.clearRecents(now: now())
        refresh(syncState: syncState)
        scheduleSynchronization()
    }

    func removeRecentSearch(id: String) {
        store.removeRecent(id: id, now: now())
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

    func preference(for mode: TransitMode) -> TransitModePreference {
        if transportPreferences.preferredModes.contains(mode) { return .preferred }
        if transportPreferences.excludedModes.contains(mode) { return .excluded }
        return .normal
    }

    func setPreference(_ preference: TransitModePreference, for mode: TransitMode) {
        var preferences = transportPreferences
        preferences.preferredModes.remove(mode)
        preferences.excludedModes.remove(mode)

        switch preference {
        case .normal:
            break
        case .preferred:
            preferences.preferredModes.insert(mode)
        case .excluded:
            preferences.excludedModes.insert(mode)
        }

        preferences.updatedAt = now()
        store.setPreferences(preferences)
        refresh(syncState: syncState)
        scheduleSynchronization()
    }

    func resetPreferences() {
        var preferences = TransportPreferences.empty
        preferences.updatedAt = now()
        store.setPreferences(preferences)
        refresh(syncState: syncState)
        scheduleSynchronization()
    }

    func makeExport(exportedAt: Date? = nil) -> AccountExport {
        AccountExport(snapshot: snapshot, exportedAt: exportedAt ?? now())
    }

    func synchronize() {
        scheduleSynchronization(fetchCanonical: true)
    }

    func delete(using proof: AccountDeletionProof) async throws {
        guard case .user(let userID) = activeScope else { return }
        try await remote.delete(using: proof)
        guard activeScope == .user(userID) else { return }
        synchronizationTask?.cancel()
        synchronizationTask = nil
        store.erase(userID: userID)
        activeScope = nil
        state = .inactive
    }

    private func scheduleSynchronization(fetchCanonical: Bool = false) {
        guard synchronizationEnabled, case .user(let userID) = activeScope else {
            refresh(syncState: .local)
            return
        }
        guard synchronizationTask == nil else { return }
        refresh(syncState: .syncing)
        synchronizationTask = Task { [weak self] in
            guard let self else { return }
            await self.synchronize(userID: userID, fetchCanonical: fetchCanonical)
        }
    }

    private func synchronize(userID: String, fetchCanonical: Bool) async {
        var shouldFetchCanonical = fetchCanonical
        var lastSyncedAt: Date?
        defer { synchronizationTask = nil }

        do {
            while !Task.isCancelled {
                guard
                    activeScope == .user(userID),
                    let pending = store.pendingSync(),
                    pending.userID == userID
                else { return }

                if pending.operations.isEmpty, !shouldFetchCanonical { break }
                let result = try await remote.synchronize(pending.operations)
                try Task.checkCancellation()
                guard
                    activeScope == .user(userID),
                    store.pendingSync()?.userID == userID
                else { return }

                store.apply(result)
                lastSyncedAt = result.syncedAt
                shouldFetchCanonical = false
                refresh(syncState: .syncing)
            }

            guard activeScope == .user(userID) else { return }
            refresh(syncState: .synced(lastSyncedAt ?? now()))
        } catch is CancellationError {
        } catch {
            guard activeScope == .user(userID) else { return }
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
        guard let activeScope else {
            state = .inactive
            return
        }

        switch activeScope {
        case .anonymous:
            let refreshed = AccountState.local(store.currentSnapshot())
            if state != refreshed { state = refreshed }
        case .user:
            let refreshed = AccountState.active(store.currentSnapshot(), syncState)
            if state != refreshed { state = refreshed }
        }
    }
}
