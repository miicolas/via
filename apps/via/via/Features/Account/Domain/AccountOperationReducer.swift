import Foundation

enum AccountMutation: Sendable {
    case toggleFavorite(stationID: StationID, name: String, coordinate: GeoCoordinate?, at: Date)
    case removeFavorite(stationID: String, at: Date)
    case savePlace(SavedPlace)
    case removePlace(id: String, at: Date)
    case setPreferences(TransportPreferences)
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

        case .setPreferences(let preferences):
            operations = [AccountSyncOperation(
                kind: .preferencesSet,
                occurredAt: preferences.updatedAt,
                preferences: preferences
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
            normalize(&snapshot)
        case .placeRemove:
            snapshot.places.removeAll { $0.id == operation.placeID }
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
    }
}
