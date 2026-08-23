import Foundation

enum AccountMutation: Sendable {
    case toggleFavorite(stationID: StationID, name: String, coordinate: GeoCoordinate?, at: Date)
    case removeFavorite(stationID: String, at: Date)
    case savePlace(SavedPlace)
    case removePlace(id: String, at: Date)
    case saveDestination(SavedDestination)
    case removeDestination(id: UUID, at: Date)
    case setPreferences(TransportPreferences)
    case setNotificationPreferences(NotificationPreferences)
    case saveNotificationSchedule(NotificationSchedule)
    case removeNotificationSchedule(id: String, at: Date)
    case saveNotificationAlert(NotificationAlertSubscription)
    case removeNotificationAlert(id: String, at: Date)
}

struct AccountMutationResult: Sendable {
    var snapshot: AccountLocalSnapshot
    let operations: [AccountSyncOperation]
    let favoriteIsSaved: Bool?
}

/// Single owner of account operation semantics. Immediate local mutations,
/// post-sync replay, anonymous migration, and stateful test adapters all cross
/// this interface so identity, ordering, role uniqueness, and limits cannot
/// drift between implementations.
enum AccountOperationReducer {
    static func reduce(
        _ mutation: AccountMutation,
        in current: AccountLocalSnapshot
    ) -> AccountMutationResult {
        var snapshot = current
        let operations: [AccountSyncOperation]
        let favoriteIsSaved: Bool?

        switch mutation {
        case .toggleFavorite(let stationID, let name, let coordinate, let date):
            if snapshot.favorites.contains(where: { $0.stationID == stationID.rawValue }) {
                operations = [AccountSyncOperation(
                    kind: .favoriteRemove,
                    occurredAt: date,
                    stationID: stationID.rawValue
                )]
                favoriteIsSaved = false
            } else {
                let before = Set(snapshot.favorites.map(\.stationID))
                let favorite = FavoriteStation(
                    stationID: stationID.rawValue,
                    name: name,
                    coordinate: coordinate,
                    savedAt: date,
                    updatedAt: date
                )
                let upsert = AccountSyncOperation(
                    kind: .favoriteUpsert,
                    occurredAt: date,
                    station: favorite
                )
                replay(upsert, into: &snapshot)
                let after = Set(snapshot.favorites.map(\.stationID))
                let evictions = before.subtracting(after).map {
                    AccountSyncOperation(kind: .favoriteRemove, occurredAt: date, stationID: $0)
                }
                return AccountMutationResult(
                    snapshot: snapshot,
                    operations: [upsert] + evictions,
                    favoriteIsSaved: true
                )
            }

        case .removeFavorite(let stationID, let date):
            operations = [AccountSyncOperation(
                kind: .favoriteRemove,
                occurredAt: date,
                stationID: stationID
            )]
            favoriteIsSaved = nil

        case .savePlace(let place):
            operations = [AccountSyncOperation(
                kind: .placeUpsert,
                occurredAt: place.updatedAt,
                place: place
            )]
            favoriteIsSaved = nil

        case .removePlace(let id, let date):
            operations = [AccountSyncOperation(
                kind: .placeRemove,
                occurredAt: date,
                placeID: id
            )]
            favoriteIsSaved = nil

        case .saveDestination(let destination):
            operations = [AccountSyncOperation(
                kind: .destinationUpsert,
                occurredAt: destination.updatedAt,
                destination: destination
            )]
            favoriteIsSaved = nil

        case .removeDestination(let id, let date):
            operations = [AccountSyncOperation(
                kind: .destinationRemove,
                occurredAt: date,
                destinationID: id
            )]
            favoriteIsSaved = nil

        case .setPreferences(let preferences):
            operations = [AccountSyncOperation(
                kind: .preferencesSet,
                occurredAt: preferences.updatedAt,
                preferences: preferences
            )]
            favoriteIsSaved = nil

        case .setNotificationPreferences(let preferences):
            operations = [AccountSyncOperation(
                kind: .notificationPreferencesSet,
                occurredAt: preferences.updatedAt,
                notificationPreferences: preferences
            )]
            favoriteIsSaved = nil

        case .saveNotificationSchedule(let schedule):
            operations = [AccountSyncOperation(
                kind: .notificationScheduleUpsert,
                occurredAt: schedule.updatedAt,
                schedule: schedule
            )]
            favoriteIsSaved = nil

        case .removeNotificationSchedule(let id, let date):
            operations = [AccountSyncOperation(
                kind: .notificationScheduleRemove,
                occurredAt: date,
                scheduleID: id
            )]
            favoriteIsSaved = nil

        case .saveNotificationAlert(let alert):
            operations = [AccountSyncOperation(
                kind: .notificationAlertUpsert,
                occurredAt: alert.updatedAt,
                alertSubscription: alert
            )]
            favoriteIsSaved = nil

        case .removeNotificationAlert(let id, let date):
            operations = [AccountSyncOperation(
                kind: .notificationAlertRemove,
                occurredAt: date,
                alertSubscriptionID: id
            )]
            favoriteIsSaved = nil
        }

        for operation in operations {
            replay(operation, into: &snapshot)
        }
        return AccountMutationResult(
            snapshot: snapshot,
            operations: operations,
            favoriteIsSaved: favoriteIsSaved
        )
    }

    static func replay(
        _ operation: AccountSyncOperation,
        into snapshot: inout AccountLocalSnapshot
    ) {
        switch operation.kind {
        case .favoriteUpsert:
            guard let station = operation.station else { return }
            snapshot.favorites.removeAll { $0.stationID == station.stationID }
            snapshot.favorites.insert(station, at: 0)
            snapshot.favorites = Array(snapshot.favorites.prefix(AccountLocalSnapshot.favoriteLimit))
        case .favoriteRemove:
            snapshot.favorites.removeAll { $0.stationID == operation.stationID }
        case .recentUpsert, .recentRemove, .recentClear:
            // Kept in the wire enum for older app versions only. Search
            // history is device-local and never enters account state.
            return
        case .preferencesSet:
            if let preferences = operation.preferences { snapshot.preferences = preferences }
        case .placeUpsert:
            guard let place = operation.place else { return }
            if let existing = snapshot.places.first(where: { $0.id == place.id }),
               existing.updatedAt > place.updatedAt {
                return
            }
            snapshot.places.removeAll { $0.id == place.id }
            guard !snapshot.places.contains(where: {
                $0.role == place.role && $0.updatedAt > place.updatedAt
            }) else {
                return
            }
            snapshot.places.removeAll { $0.role == place.role }
            snapshot.places.insert(place, at: 0)
            snapshot.destinations.removeAll { $0.destinationID == place.id }
            normalize(&snapshot)
        case .placeRemove:
            snapshot.places.removeAll { $0.id == operation.placeID }
        case .destinationUpsert:
            guard let destination = operation.destination else { return }
            guard !snapshot.places.contains(where: { $0.id == destination.destinationID }) else {
                snapshot.destinations.removeAll { $0.destinationID == destination.destinationID }
                return
            }
            if let existing = snapshot.destinations.first(where: { $0.id == destination.id }),
               existing.updatedAt > destination.updatedAt {
                return
            }
            if let duplicate = snapshot.destinations.first(where: {
                $0.destinationID == destination.destinationID && $0.id != destination.id
            }), duplicate.updatedAt > destination.updatedAt {
                return
            }
            snapshot.destinations.removeAll {
                $0.id == destination.id || $0.destinationID == destination.destinationID
            }
            snapshot.destinations.append(destination)
            normalize(&snapshot)
        case .destinationRemove:
            snapshot.destinations.removeAll { $0.id == operation.destinationID }
        case .notificationPreferencesSet:
            if let preferences = operation.notificationPreferences,
               preferences.updatedAt >= snapshot.notificationPreferences.updatedAt {
                snapshot.notificationPreferences = preferences
            }
        case .notificationScheduleUpsert:
            guard let schedule = operation.schedule else { return }
            if let existing = snapshot.notificationSchedules.first(where: { $0.id == schedule.id }),
               existing.updatedAt > schedule.updatedAt {
                return
            }
            snapshot.notificationSchedules.removeAll { $0.id == schedule.id }
            snapshot.notificationSchedules.insert(schedule, at: 0)
            snapshot.notificationSchedules = Array(snapshot.notificationSchedules
                .filter { $0.deletedAt == nil }
                .sorted { $0.savedAt > $1.savedAt }
                .prefix(20))
        case .notificationScheduleRemove:
            snapshot.notificationSchedules.removeAll { $0.id == operation.scheduleID }
        case .notificationAlertUpsert:
            guard let alert = operation.alertSubscription else { return }
            if let existing = snapshot.notificationAlerts.first(where: { $0.id == alert.id }),
               existing.updatedAt > alert.updatedAt {
                return
            }
            snapshot.notificationAlerts.removeAll { $0.id == alert.id }
            snapshot.notificationAlerts.insert(alert, at: 0)
            snapshot.notificationAlerts = Array(snapshot.notificationAlerts
                .filter { $0.deletedAt == nil }
                .sorted { $0.savedAt > $1.savedAt }
                .prefix(40))
        case .notificationAlertRemove:
            snapshot.notificationAlerts.removeAll { $0.id == operation.alertSubscriptionID }
        }
    }

    static func normalize(_ snapshot: inout AccountLocalSnapshot) {
        snapshot.favorites = Array(
            snapshot.favorites.sorted { $0.savedAt > $1.savedAt }
                .prefix(AccountLocalSnapshot.favoriteLimit)
        )
        for role in [SavedPlace.Role.home, .work] {
            let matching = snapshot.places
                .filter { $0.role == role }
                .sorted { $0.updatedAt > $1.updatedAt }
            guard let newest = matching.first else { continue }
            snapshot.places.removeAll { $0.role == role && $0.id != newest.id }
        }
        let pinnedIDs = Set(snapshot.places.map(\.id))
        snapshot.destinations.removeAll { pinnedIDs.contains($0.destinationID) }
        snapshot.destinations = Array(
            snapshot.destinations
                .sorted {
                    if $0.position != $1.position { return $0.position < $1.position }
                    return $0.id.uuidString < $1.id.uuidString
                }
                .prefix(AccountLocalSnapshot.destinationLimit)
        )
    }
}
