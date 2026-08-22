import Foundation

/// Device persistence for both the anonymous workspace and authenticated user
/// workspaces. The store deliberately keeps the two keys separate so signing
/// out never destroys either copy.
final class AccountLocalStore: @unchecked Sendable {
    private static let legacyRecentsKey = "via.recent-searches.v1"
    private static let accountPrefix = "via.account-data.v1."
    private static let anonymousKey = "anonymous"
    private static let pendingOperationLimit = 500

    private let defaults: UserDefaults
    private let lock = NSLock()
    private var activeScope: AccountScope?
    /// The decoded snapshot for the last scope touched, so reads on UI paths
    /// do not re-decode the whole payload from UserDefaults each time.
    private var cachedSnapshot: (scope: AccountScope, snapshot: AccountLocalSnapshot)?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func activateAnonymous() {
        activate(scope: .anonymous)
    }

    func activate(userID: String) {
        activate(scope: .user(userID))
    }

    func deactivate() {
        locked { activeScope = nil }
    }

    func erase(userID: String) {
        erase(scope: .user(userID))
    }

    /// Clears every Via account workspace stored on this device. This is
    /// intentionally broader than erasing one scope: after an account wipe,
    /// an older anonymous workspace must not reappear on the next launch.
    func eraseAll() {
        locked {
            defaults.removeObject(forKey: Self.legacyRecentsKey)
            defaults.removeObject(forKey: storageKey(for: .anonymous))
            if let activeScope {
                defaults.removeObject(forKey: storageKey(for: activeScope))
            }
            cachedSnapshot = nil
            activeScope = nil
        }
    }

    /// Folds the anonymous device workspace into a user workspace on first
    /// sign-in. Individual values use their domain timestamp as the LWW
    /// conflict key; pending anonymous operations are carried over so the
    /// server can apply the same decision against its canonical copy.
    func mergeAnonymous(into userID: String) {
        locked {
            guard activeScope == .user(userID) else { return }

            let anonymous = load(for: .anonymous)
            guard !anonymous.isEmpty else { return }

            var user = load(for: .user(userID))
            let merged = merge(user: user, anonymous: anonymous)
            user.favorites = merged.favorites
            user.places = merged.places
            user.preferences = merged.preferences
            user.notificationPreferences = merged.notificationPreferences
            user.notificationSchedules = merged.notificationSchedules
            user.notificationAlerts = merged.notificationAlerts

            let carriedOperations = anonymous.pendingOperations.isEmpty
                ? syntheticOperations(for: anonymous)
                : anonymous.pendingOperations
            user.pendingOperations.append(contentsOf: carriedOperations)
            trimOperations(&user)
            save(user, for: .user(userID))

            defaults.removeObject(forKey: storageKey(for: .anonymous))
            if cachedSnapshot?.scope == .anonymous { cachedSnapshot = nil }
        }
    }

    func currentSnapshot() -> AccountSnapshot {
        locked {
            let snapshot = loadActive()
            return AccountSnapshot(
                favorites: snapshot.favorites.sorted { $0.savedAt > $1.savedAt },
                places: snapshot.places.sorted { $0.savedAt > $1.savedAt },
                transportPreferences: snapshot.preferences,
                notificationPreferences: snapshot.notificationPreferences,
                notificationSchedules: snapshot.notificationSchedules,
                notificationAlerts: snapshot.notificationAlerts
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
            mutate(.toggleFavorite(
                stationID: stationID,
                name: name,
                coordinate: coordinate,
                at: now
            ))?.favoriteIsSaved ?? false
        }
    }

    func removeFavorite(stationID: String, now: Date = .now) {
        locked {
            _ = mutate(.removeFavorite(stationID: stationID, at: now))
        }
    }

    func savePlace(_ place: SavedPlace) {
        locked {
            _ = mutate(.savePlace(place))
        }
    }

    func removePlace(id: String, now: Date = .now) {
        locked {
            _ = mutate(.removePlace(id: id, at: now))
        }
    }

    func setPreferences(_ preferences: TransportPreferences) {
        locked {
            _ = mutate(.setPreferences(preferences))
        }
    }

    func setNotificationPreferences(_ preferences: NotificationPreferences) {
        locked {
            _ = mutate(.setNotificationPreferences(preferences))
        }
    }

    func saveNotificationSchedule(_ schedule: NotificationSchedule) {
        locked {
            _ = mutate(.saveNotificationSchedule(schedule))
        }
    }

    func removeNotificationSchedule(id: String, now: Date = .now) {
        locked {
            _ = mutate(.removeNotificationSchedule(id: id, at: now))
        }
    }

    func saveNotificationAlert(_ alert: NotificationAlertSubscription) {
        locked {
            _ = mutate(.saveNotificationAlert(alert))
        }
    }

    func removeNotificationAlert(id: String, now: Date = .now) {
        locked {
            _ = mutate(.removeNotificationAlert(id: id, at: now))
        }
    }

    func pendingSync() -> (userID: String, operations: [AccountSyncOperation])? {
        locked {
            guard case .user(let userID) = activeScope else { return nil }
            return (userID, load(for: .user(userID)).pendingOperations)
        }
    }

    func apply(_ result: AccountSyncResult) {
        locked {
            guard case .user(let userID) = activeScope else { return }
            let acknowledged = Set(result.appliedOperationIDs)
            let remaining = load(for: .user(userID)).pendingOperations.filter {
                !acknowledged.contains($0.operationID)
            }
            var snapshot = AccountLocalSnapshot(
                favorites: result.favorites,
                places: result.places,
                preferences: result.preferences,
                notificationPreferences: result.notificationPreferences,
                notificationSchedules: result.notificationSchedules,
                notificationAlerts: result.notificationAlerts,
                pendingOperations: remaining
            )
            for operation in remaining {
                AccountOperationReducer.replay(operation, into: &snapshot)
            }
            save(snapshot, for: .user(userID))
        }
    }

    private func activate(scope: AccountScope) {
        locked {
            activeScope = scope
            defaults.removeObject(forKey: Self.legacyRecentsKey)
            let key = storageKey(for: scope)
            guard defaults.data(forKey: key) == nil else { return }

            save(AccountLocalSnapshot(), for: scope)
        }
    }

    private func erase(scope: AccountScope) {
        defaults.removeObject(forKey: storageKey(for: scope))
        if cachedSnapshot?.scope == scope { cachedSnapshot = nil }
        if activeScope == scope { activeScope = nil }
    }

    private func loadActive() -> AccountLocalSnapshot {
        guard let activeScope else { return AccountLocalSnapshot() }
        return load(for: activeScope)
    }

    private func load(for scope: AccountScope) -> AccountLocalSnapshot {
        if let cachedSnapshot, cachedSnapshot.scope == scope { return cachedSnapshot.snapshot }
        let stored = defaults.data(forKey: storageKey(for: scope))
        var snapshot = stored
            .flatMap { try? JSONDecoder.via.decode(AccountLocalSnapshot.self, from: $0) }
            ?? AccountLocalSnapshot()
        snapshot.pendingOperations.removeAll { $0.kind.isLegacyRecent }
        // Re-encoding also drops the retired `recents` key that builds before
        // device-local search history wrote into this blob, so the history
        // does not survive on disk.
        if let rewritten = try? JSONEncoder.via.encode(snapshot), rewritten != stored {
            defaults.set(rewritten, forKey: storageKey(for: scope))
        }
        cachedSnapshot = (scope, snapshot)
        return snapshot
    }

    private func save(_ snapshot: AccountLocalSnapshot, for scope: AccountScope) {
        cachedSnapshot = (scope, snapshot)
        guard let data = try? JSONEncoder.via.encode(snapshot) else { return }
        defaults.set(data, forKey: storageKey(for: scope))
    }

    private func mutate(_ mutation: AccountMutation) -> AccountMutationResult? {
        guard let scope = activeScope else { return nil }
        let current = load(for: scope)
        let result = AccountOperationReducer.reduce(mutation, in: current)
        var persisted = result.snapshot
        persisted.pendingOperations.append(contentsOf: result.operations)
        trimOperations(&persisted)
        save(persisted, for: scope)
        return result
    }

    private func storageKey(for scope: AccountScope) -> String {
        switch scope {
        case .anonymous:
            return Self.accountPrefix + Self.anonymousKey
        case .user(let userID):
            return Self.accountPrefix + userID
        }
    }

    private func merge(
        user: AccountLocalSnapshot,
        anonymous: AccountLocalSnapshot
    ) -> AccountLocalSnapshot {
        var favoritesByID = Dictionary(uniqueKeysWithValues: user.favorites.map { ($0.stationID, $0) })
        for favorite in anonymous.favorites {
            if favorite.updatedAt >= (favoritesByID[favorite.stationID]?.updatedAt ?? .distantPast) {
                favoritesByID[favorite.stationID] = favorite
            }
        }

        var placesByID = Dictionary(uniqueKeysWithValues: user.places.map { ($0.id, $0) })
        for place in anonymous.places {
            if place.updatedAt >= (placesByID[place.id]?.updatedAt ?? .distantPast) {
                placesByID[place.id] = place
            }
        }

        var places = placesByID.values.sorted { $0.updatedAt > $1.updatedAt }
        for role in [SavedPlace.Role.home, .work] {
            let matching = places.filter { $0.role == role }
            if matching.count > 1, let newest = matching.max(by: { $0.updatedAt < $1.updatedAt }) {
                places.removeAll { $0.role == role && $0.id != newest.id }
            }
        }
        var merged = AccountLocalSnapshot(
            favorites: Array(favoritesByID.values.sorted { $0.savedAt > $1.savedAt }.prefix(AccountLocalSnapshot.favoriteLimit)),
            places: places,
            preferences: anonymous.preferences.updatedAt >= user.preferences.updatedAt
                ? anonymous.preferences
                : user.preferences,
            notificationPreferences: anonymous.notificationPreferences.updatedAt >= user.notificationPreferences.updatedAt
                ? anonymous.notificationPreferences
                : user.notificationPreferences,
            notificationSchedules: mergeSchedules(user: user.notificationSchedules, anonymous: anonymous.notificationSchedules),
            notificationAlerts: mergeAlerts(user: user.notificationAlerts, anonymous: anonymous.notificationAlerts),
            pendingOperations: []
        )

        // A remove is a timestamped tombstone even though the compact local
        // snapshot only stores live values. Apply anonymous tombstones against
        // the authenticated copy before carrying the operations over.
        for operation in anonymous.pendingOperations {
            switch operation.kind {
            case .favoriteRemove:
                merged.favorites.removeAll {
                    $0.stationID == operation.stationID && $0.updatedAt <= operation.occurredAt
                }
            case .placeRemove:
                merged.places.removeAll {
                    $0.id == operation.placeID && $0.updatedAt <= operation.occurredAt
                }
            case .notificationScheduleRemove:
                merged.notificationSchedules.removeAll {
                    $0.id == operation.scheduleID && $0.updatedAt <= operation.occurredAt
                }
            case .notificationAlertRemove:
                merged.notificationAlerts.removeAll {
                    $0.id == operation.alertSubscriptionID && $0.updatedAt <= operation.occurredAt
                }
            default:
                break
            }
        }
        AccountOperationReducer.normalize(&merged)
        return merged
    }

    private func syntheticOperations(for snapshot: AccountLocalSnapshot) -> [AccountSyncOperation] {
        var operations = snapshot.favorites.map {
            AccountSyncOperation(kind: .favoriteUpsert, occurredAt: $0.updatedAt, station: $0)
        }
        operations.append(contentsOf: snapshot.places.map {
            AccountSyncOperation(kind: .placeUpsert, occurredAt: $0.updatedAt, place: $0)
        })
        if snapshot.preferences.updatedAt > .distantPast {
            operations.append(AccountSyncOperation(
                kind: .preferencesSet,
                occurredAt: snapshot.preferences.updatedAt,
                preferences: snapshot.preferences
            ))
        }
        if snapshot.notificationPreferences.updatedAt > .distantPast {
            operations.append(AccountSyncOperation(
                kind: .notificationPreferencesSet,
                occurredAt: snapshot.notificationPreferences.updatedAt,
                notificationPreferences: snapshot.notificationPreferences
            ))
        }
        operations.append(contentsOf: snapshot.notificationSchedules.map {
            AccountSyncOperation(kind: .notificationScheduleUpsert, occurredAt: $0.updatedAt, schedule: $0)
        })
        operations.append(contentsOf: snapshot.notificationAlerts.map {
            AccountSyncOperation(kind: .notificationAlertUpsert, occurredAt: $0.updatedAt, alertSubscription: $0)
        })
        return operations
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

private extension AccountLocalSnapshot {
    var isEmpty: Bool {
        favorites.isEmpty
            && places.isEmpty
            && preferences == .empty
            && notificationPreferences == .default
            && notificationSchedules.isEmpty
            && notificationAlerts.isEmpty
            && pendingOperations.isEmpty
    }
}

private func mergeSchedules(
    user: [NotificationSchedule],
    anonymous: [NotificationSchedule]
) -> [NotificationSchedule] {
    var byID = Dictionary(uniqueKeysWithValues: user.map { ($0.id, $0) })
    for value in anonymous where value.updatedAt >= (byID[value.id]?.updatedAt ?? .distantPast) {
        byID[value.id] = value
    }
    return Array(byID.values.filter { $0.deletedAt == nil }.sorted { $0.savedAt > $1.savedAt }.prefix(20))
}

private func mergeAlerts(
    user: [NotificationAlertSubscription],
    anonymous: [NotificationAlertSubscription]
) -> [NotificationAlertSubscription] {
    var byID = Dictionary(uniqueKeysWithValues: user.map { ($0.id, $0) })
    for value in anonymous where value.updatedAt >= (byID[value.id]?.updatedAt ?? .distantPast) {
        byID[value.id] = value
    }
    return Array(byID.values.filter { $0.deletedAt == nil }.sorted { $0.savedAt > $1.savedAt }.prefix(40))
}

private extension AccountSyncOperation.Kind {
    var isLegacyRecent: Bool {
        switch self {
        case .recentUpsert, .recentRemove, .recentClear:
            true
        default:
            false
        }
    }
}
