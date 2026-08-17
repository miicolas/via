import Foundation

struct FavoriteStation: Codable, Sendable, Hashable, Identifiable {
    let stationID: String
    let name: String
    let savedAt: Date
    let updatedAt: Date

    var id: String { stationID }

    private enum CodingKeys: String, CodingKey {
        case stationID = "stationId"
        case name
        case savedAt
        case updatedAt
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
    }

    let operationID: UUID
    let kind: Kind
    let occurredAt: Date
    let station: FavoriteStation?
    let stationID: String?
    let recentID: String?
    let recent: RecentSearch?
    let preferences: TransportPreferences?

    init(
        operationID: UUID = UUID(),
        kind: Kind,
        occurredAt: Date,
        station: FavoriteStation? = nil,
        stationID: String? = nil,
        recentID: String? = nil,
        recent: RecentSearch? = nil,
        preferences: TransportPreferences? = nil
    ) {
        self.operationID = operationID
        self.kind = kind
        self.occurredAt = occurredAt
        self.station = station
        self.stationID = stationID
        self.recentID = recentID
        self.recent = recent
        self.preferences = preferences
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
    }
}

struct AccountSyncResult: Codable, Sendable, Hashable {
    let appliedOperationIDs: [UUID]
    let favorites: [FavoriteStation]
    let recents: [RecentSearch]
    let preferences: TransportPreferences
    let syncedAt: Date

    private enum CodingKeys: String, CodingKey {
        case appliedOperationIDs = "appliedOperationIds"
        case favorites
        case recents
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
    var transportPreferences: TransportPreferences

    static let empty = AccountSnapshot(
        favorites: [],
        recentSearches: [],
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

    var favorites: [FavoriteStation] = []
    var recents: [RecentSearch] = []
    var preferences: TransportPreferences = .empty
    var pendingOperations: [AccountSyncOperation] = []
}
