import Foundation

final class AccountLocalStore: @unchecked Sendable {
    private static let legacyRecentsKey = "via.recent-searches.v1"
    private static let accountPrefix = "via.account-data.v1."
    private static let pendingOperationLimit = 500

    private let defaults: UserDefaults
    private let lock = NSLock()
    private var activeUserID: String?
    /// The decoded snapshot for the last user touched, so reads on UI paths do
    /// not re-decode the whole payload from UserDefaults each time.
    private var cachedSnapshot: (userID: String, snapshot: AccountLocalSnapshot)?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func activate(userID: String) {
        locked {
            activeUserID = userID
            let key = Self.accountPrefix + userID
            guard defaults.data(forKey: key) == nil else { return }

            var snapshot = AccountLocalSnapshot()
            if let legacy = defaults.data(forKey: Self.legacyRecentsKey),
               let recents = try? JSONDecoder.via.decode([RecentSearch].self, from: legacy) {
                snapshot.recents = Array(
                    recents.sorted { $0.savedAt > $1.savedAt }.prefix(AccountLocalSnapshot.recentLimit)
                )
                snapshot.pendingOperations = snapshot.recents.map(Self.recentUpsertOperation)
                defaults.removeObject(forKey: Self.legacyRecentsKey)
            }
            save(snapshot, for: userID)
        }
    }

    func deactivate() {
        locked { activeUserID = nil }
    }

    func erase(userID: String) {
        locked {
            defaults.removeObject(forKey: Self.accountPrefix + userID)
            if cachedSnapshot?.userID == userID { cachedSnapshot = nil }
            if activeUserID == userID { activeUserID = nil }
        }
    }

    func currentSnapshot() -> AccountSnapshot {
        locked {
            let snapshot = loadActive()
            return AccountSnapshot(
                favorites: snapshot.favorites.sorted { $0.savedAt > $1.savedAt },
                recentSearches: snapshot.recents.sorted { $0.savedAt > $1.savedAt },
                places: snapshot.places.sorted { $0.savedAt > $1.savedAt },
                transportPreferences: snapshot.preferences
            )
        }
    }

    @discardableResult
    func toggleFavorite(
        stationID: StationID,
        name: String,
        coordinate: GeoCoordinate? = nil,
        now: Date = .now
    ) -> Bool {
        locked {
            guard let userID = activeUserID else { return false }
            var snapshot = load(for: userID)
            if let index = snapshot.favorites.firstIndex(where: { $0.stationID == stationID.rawValue }) {
                snapshot.favorites.remove(at: index)
                snapshot.pendingOperations.append(AccountSyncOperation(
                    kind: .favoriteRemove,
                    occurredAt: now,
                    stationID: stationID.rawValue
                ))
                trimOperations(&snapshot)
                save(snapshot, for: userID)
                return false
            }

            let favorite = FavoriteStation(
                stationID: stationID.rawValue,
                name: name,
                coordinate: coordinate,
                savedAt: now,
                updatedAt: now
            )
            snapshot.favorites.insert(favorite, at: 0)
            snapshot.pendingOperations.append(AccountSyncOperation(
                kind: .favoriteUpsert,
                occurredAt: now,
                station: favorite
            ))

            if snapshot.favorites.count > AccountLocalSnapshot.favoriteLimit {
                let removed = snapshot.favorites.removeLast()
                snapshot.pendingOperations.append(AccountSyncOperation(
                    kind: .favoriteRemove,
                    occurredAt: now,
                    stationID: removed.stationID
                ))
            }
            trimOperations(&snapshot)
            save(snapshot, for: userID)
            return true
        }
    }

    func removeFavorite(stationID: String, now: Date = .now) {
        locked {
            guard let userID = activeUserID else { return }
            var snapshot = load(for: userID)
            snapshot.favorites.removeAll { $0.stationID == stationID }
            snapshot.pendingOperations.append(AccountSyncOperation(
                kind: .favoriteRemove,
                occurredAt: now,
                stationID: stationID
            ))
            trimOperations(&snapshot)
            save(snapshot, for: userID)
        }
    }

    func upsertRecent(_ recent: RecentSearch) {
        locked {
            guard let userID = activeUserID else { return }
            var snapshot = load(for: userID)
            snapshot.recents.removeAll { $0.id == recent.id }
            snapshot.recents.insert(recent, at: 0)
            snapshot.recents = Array(snapshot.recents.prefix(AccountLocalSnapshot.recentLimit))
            snapshot.pendingOperations.append(Self.recentUpsertOperation(recent))
            trimOperations(&snapshot)
            save(snapshot, for: userID)
        }
    }

    func removeRecent(id: String, now: Date = .now) {
        locked {
            guard let userID = activeUserID else { return }
            var snapshot = load(for: userID)
            snapshot.recents.removeAll { $0.id == id }
            snapshot.pendingOperations.append(AccountSyncOperation(
                kind: .recentRemove,
                occurredAt: now,
                recentID: id
            ))
            trimOperations(&snapshot)
            save(snapshot, for: userID)
        }
    }

    func clearRecents(now: Date = .now) {
        locked {
            guard let userID = activeUserID else { return }
            var snapshot = load(for: userID)
            snapshot.recents = []
            snapshot.pendingOperations.append(AccountSyncOperation(
                kind: .recentClear,
                occurredAt: now
            ))
            trimOperations(&snapshot)
            save(snapshot, for: userID)
        }
    }

    func savePlace(_ place: SavedPlace) {
        locked {
            guard let userID = activeUserID else { return }
            var snapshot = load(for: userID)
            // The replay reducer is the single owner of place-op semantics so
            // local saves and post-sync replays cannot drift apart.
            let operation = AccountSyncOperation(
                kind: .placeUpsert,
                occurredAt: place.updatedAt,
                place: place
            )
            replay(operation, into: &snapshot)
            snapshot.pendingOperations.append(operation)
            trimOperations(&snapshot)
            save(snapshot, for: userID)
        }
    }

    func removePlace(id: String, now: Date = .now) {
        locked {
            guard let userID = activeUserID else { return }
            var snapshot = load(for: userID)
            snapshot.places.removeAll { $0.id == id }
            snapshot.pendingOperations.append(AccountSyncOperation(
                kind: .placeRemove,
                occurredAt: now,
                placeID: id
            ))
            trimOperations(&snapshot)
            save(snapshot, for: userID)
        }
    }

    func setPreferences(_ preferences: TransportPreferences) {
        locked {
            guard let userID = activeUserID else { return }
            var snapshot = load(for: userID)
            snapshot.preferences = preferences
            snapshot.pendingOperations.append(AccountSyncOperation(
                kind: .preferencesSet,
                occurredAt: preferences.updatedAt,
                preferences: preferences
            ))
            trimOperations(&snapshot)
            save(snapshot, for: userID)
        }
    }

    func pendingSync() -> (userID: String, operations: [AccountSyncOperation])? {
        locked {
            guard let userID = activeUserID else { return nil }
            return (userID, load(for: userID).pendingOperations)
        }
    }

    func apply(_ result: AccountSyncResult) {
        locked {
            guard let userID = activeUserID else { return }
            let acknowledged = Set(result.appliedOperationIDs)
            let remaining = load(for: userID).pendingOperations.filter {
                !acknowledged.contains($0.operationID)
            }
            var snapshot = AccountLocalSnapshot(
                favorites: result.favorites,
                recents: result.recents,
                places: result.places,
                preferences: result.preferences,
                pendingOperations: remaining
            )
            for operation in remaining { replay(operation, into: &snapshot) }
            save(snapshot, for: userID)
        }
    }

    private func loadActive() -> AccountLocalSnapshot {
        guard let activeUserID else { return AccountLocalSnapshot() }
        return load(for: activeUserID)
    }

    private func load(for userID: String) -> AccountLocalSnapshot {
        if let cachedSnapshot, cachedSnapshot.userID == userID { return cachedSnapshot.snapshot }
        let snapshot = defaults.data(forKey: Self.accountPrefix + userID)
            .flatMap { try? JSONDecoder.via.decode(AccountLocalSnapshot.self, from: $0) }
            ?? AccountLocalSnapshot()
        cachedSnapshot = (userID, snapshot)
        return snapshot
    }

    private func save(_ snapshot: AccountLocalSnapshot, for userID: String) {
        cachedSnapshot = (userID, snapshot)
        guard let data = try? JSONEncoder.via.encode(snapshot) else { return }
        defaults.set(data, forKey: Self.accountPrefix + userID)
    }

    private func replay(_ operation: AccountSyncOperation, into snapshot: inout AccountLocalSnapshot) {
        switch operation.kind {
        case .favoriteUpsert:
            guard let station = operation.station else { return }
            snapshot.favorites.removeAll { $0.stationID == station.stationID }
            snapshot.favorites.insert(station, at: 0)
            snapshot.favorites = Array(snapshot.favorites.prefix(AccountLocalSnapshot.favoriteLimit))
        case .favoriteRemove:
            snapshot.favorites.removeAll { $0.stationID == operation.stationID }
        case .recentUpsert:
            guard let recent = operation.recent else { return }
            snapshot.recents.removeAll { $0.id == recent.id }
            snapshot.recents.insert(recent, at: 0)
            snapshot.recents = Array(snapshot.recents.prefix(AccountLocalSnapshot.recentLimit))
        case .recentRemove:
            snapshot.recents.removeAll { $0.id == operation.recentID }
        case .recentClear:
            snapshot.recents.removeAll { $0.savedAt <= operation.occurredAt }
        case .preferencesSet:
            if let preferences = operation.preferences { snapshot.preferences = preferences }
        case .placeUpsert:
            guard let place = operation.place else { return }
            snapshot.places.removeAll { $0.id == place.id }
            if place.role != .favorite {
                // Home and work are unique: last writer evicts the previous holder.
                snapshot.places.removeAll { $0.role == place.role && $0.updatedAt <= place.updatedAt }
            }
            snapshot.places.insert(place, at: 0)
            trimFavoritePlaces(&snapshot)
        case .placeRemove:
            snapshot.places.removeAll { $0.id == operation.placeID }
        }
    }

    /// Favorites get trimmed to the shared limit; home and work never do.
    private func trimFavoritePlaces(_ snapshot: inout AccountLocalSnapshot) {
        let surplus = Set(
            snapshot.places
                .filter { $0.role == .favorite }
                .sorted { $0.savedAt > $1.savedAt }
                .dropFirst(AccountLocalSnapshot.favoritePlaceLimit)
                .map(\.id)
        )
        guard !surplus.isEmpty else { return }
        snapshot.places.removeAll { surplus.contains($0.id) }
    }

    private static func recentUpsertOperation(_ recent: RecentSearch) -> AccountSyncOperation {
        AccountSyncOperation(kind: .recentUpsert, occurredAt: recent.savedAt, recent: recent)
    }

    private func trimOperations(_ snapshot: inout AccountLocalSnapshot) {
        snapshot.pendingOperations = Array(snapshot.pendingOperations.suffix(Self.pendingOperationLimit))
    }

    private func locked<Value>(_ work: () -> Value) -> Value {
        lock.lock()
        defer { lock.unlock() }
        return work()
    }
}
