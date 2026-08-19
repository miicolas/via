import Foundation

struct FavoriteStation: Codable, Sendable, Hashable, Identifiable {
    let stationID: String
    let name: String
    let coordinate: GeoCoordinate?
    let savedAt: Date
    let updatedAt: Date

    init(
        stationID: String,
        name: String,
        coordinate: GeoCoordinate? = nil,
        savedAt: Date,
        updatedAt: Date
    ) {
        self.stationID = stationID
        self.name = name
        self.coordinate = coordinate
        self.savedAt = savedAt
        self.updatedAt = updatedAt
    }

    var id: String { stationID }

    private enum CodingKeys: String, CodingKey {
        case stationID = "stationId"
        case name
        case coordinate
        case savedAt
        case updatedAt
    }
}

/// A saved place with a stable role: home and work are unique, favorites are
/// an open-ended collection the UI can grow into later.
struct SavedPlace: Codable, Sendable, Hashable, Identifiable {
    enum Role: String, Codable, Sendable, CaseIterable, Identifiable {
        case home, work, favorite

        var id: String { rawValue }

        var displayTitle: String {
            switch self {
            case .home: "Maison"
            case .work: "Travail"
            case .favorite: "Lieu enregistré"
            }
        }

        var systemImage: String {
            switch self {
            case .home: "house.fill"
            case .work: "briefcase.fill"
            case .favorite: "mappin.and.ellipse"
            }
        }
    }

    let id: String
    let kind: RecentSearch.Kind
    let name: String
    let context: String?
    let coordinate: GeoCoordinate
    let role: Role
    let savedAt: Date
    let updatedAt: Date

    init(result: SearchResult, role: Role, savedAt: Date = .now) {
        self.init(recent: RecentSearch(result: result, savedAt: savedAt), role: role)
    }

    init(recent: RecentSearch, role: Role) {
        id = recent.id
        kind = recent.kind
        name = recent.name
        context = recent.context
        coordinate = recent.coordinate
        self.role = role
        savedAt = recent.savedAt
        updatedAt = recent.savedAt
    }

    /// The `SearchResult` ↔ persistence codec lives on `RecentSearch`; a
    /// saved place is that snapshot plus a role and LWW timestamp.
    var searchResult: SearchResult {
        RecentSearch(
            id: id,
            kind: kind,
            name: name,
            context: context,
            coordinate: coordinate,
            savedAt: savedAt
        ).searchResult
    }
}

struct TransportPreferences: Codable, Sendable, Hashable {
    var preferredModes: Set<TransitMode>
    var excludedModes: Set<TransitMode>
    var updatedAt: Date

    static let empty = TransportPreferences(
        preferredModes: [],
        excludedModes: [],
        updatedAt: .distantPast
    )
}

struct AccountSyncOperation: Codable, Sendable, Hashable, Identifiable {
    enum Kind: String, Codable, Sendable {
        case favoriteUpsert = "favorite.upsert"
        case favoriteRemove = "favorite.remove"
        case recentUpsert = "recent.upsert"
        case recentRemove = "recent.remove"
        case recentClear = "recent.clear"
        case preferencesSet = "preferences.set"
        case placeUpsert = "place.upsert"
        case placeRemove = "place.remove"
    }

    let operationID: UUID
    let kind: Kind
    let occurredAt: Date
    let station: FavoriteStation?
    let stationID: String?
    let recentID: String?
    let recent: RecentSearch?
    let preferences: TransportPreferences?
    let place: SavedPlace?
    let placeID: String?

    init(
        operationID: UUID = UUID(),
        kind: Kind,
        occurredAt: Date,
        station: FavoriteStation? = nil,
        stationID: String? = nil,
        recentID: String? = nil,
        recent: RecentSearch? = nil,
        preferences: TransportPreferences? = nil,
        place: SavedPlace? = nil,
        placeID: String? = nil
    ) {
        self.operationID = operationID
        self.kind = kind
        self.occurredAt = occurredAt
        self.station = station
        self.stationID = stationID
        self.recentID = recentID
        self.recent = recent
        self.preferences = preferences
        self.place = place
        self.placeID = placeID
    }

    var id: UUID { operationID }

    private enum CodingKeys: String, CodingKey {
        case operationID = "operationId"
        case kind
        case occurredAt
        case station
        case stationID = "stationId"
        case recentID = "recentId"
        case recent
        case preferences
        case place
        case placeID = "placeId"
    }
}

struct AccountSyncResult: Codable, Sendable, Hashable {
    let appliedOperationIDs: [UUID]
    let favorites: [FavoriteStation]
    let recents: [RecentSearch]
    let places: [SavedPlace]
    let preferences: TransportPreferences
    let syncedAt: Date

    init(
        appliedOperationIDs: [UUID],
        favorites: [FavoriteStation],
        recents: [RecentSearch],
        places: [SavedPlace] = [],
        preferences: TransportPreferences,
        syncedAt: Date
    ) {
        self.appliedOperationIDs = appliedOperationIDs
        self.favorites = favorites
        self.recents = recents
        self.places = places
        self.preferences = preferences
        self.syncedAt = syncedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        appliedOperationIDs = try container.decode([UUID].self, forKey: .appliedOperationIDs)
        favorites = try container.decode([FavoriteStation].self, forKey: .favorites)
        recents = try container.decode([RecentSearch].self, forKey: .recents)
        // Tolerates a server that predates saved places.
        places = try container.decodeIfPresent([SavedPlace].self, forKey: .places) ?? []
        preferences = try container.decode(TransportPreferences.self, forKey: .preferences)
        syncedAt = try container.decode(Date.self, forKey: .syncedAt)
    }

    private enum CodingKeys: String, CodingKey {
        case appliedOperationIDs = "appliedOperationIds"
        case favorites
        case recents
        case places
        case preferences
        case syncedAt
    }
}

struct AccountDeletionProof: Sendable, Hashable {
    let identityToken: String
    let authorizationCode: String
    let nonce: String
}

struct AccountSnapshot: Sendable, Equatable {
    var favorites: [FavoriteStation]
    var recentSearches: [RecentSearch]
    var places: [SavedPlace]
    var transportPreferences: TransportPreferences

    static let empty = AccountSnapshot(
        favorites: [],
        recentSearches: [],
        places: [],
        transportPreferences: .empty
    )
}

enum AccountSyncState: Sendable, Equatable {
    case local
    case syncing
    case synced(Date)
    case pendingOffline
    case failed(ViaError)
}

enum AccountState: Sendable, Equatable {
    case inactive
    case active(AccountSnapshot, AccountSyncState)
}

struct AccountLocalSnapshot: Codable, Sendable, Hashable {
    /// Mirrors the server's `ACCOUNT_FAVORITE_LIMIT`; both sides trim to it.
    static let favoriteLimit = 50
    /// Mirrors the server's `ACCOUNT_RECENT_LIMIT`; both sides trim to it.
    static let recentLimit = 5
    /// Mirrors the server's `ACCOUNT_PLACE_FAVORITE_LIMIT`: favorites get
    /// trimmed, home and work always keep their slot.
    static let favoritePlaceLimit = 48

    var favorites: [FavoriteStation] = []
    var recents: [RecentSearch] = []
    var places: [SavedPlace] = []
    var preferences: TransportPreferences = .empty
    var pendingOperations: [AccountSyncOperation] = []
}
