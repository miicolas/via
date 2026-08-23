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

/// A saved place with a stable, unique home or work role. Favorite stations
/// live in `FavoriteStation` so account state has one representation for them.
struct SavedPlace: Codable, Sendable, Hashable, Identifiable {
    enum Role: String, Codable, Sendable, CaseIterable, Identifiable {
        case home, work

        var id: String { rawValue }

        var displayTitle: String {
            switch self {
            case .home: "Maison"
            case .work: "Travail"
            }
        }

        var systemImage: String {
            switch self {
            case .home: "house.fill"
            case .work: "briefcase.fill"
            }
        }
    }

    let id: String
    let kind: RecentSearch.Kind
    let name: String
    let context: String?
    let coordinate: GeoCoordinate
    let role: Role
    let systemImage: String
    let savedAt: Date
    let updatedAt: Date

    init(
        result: SearchResult,
        role: Role,
        systemImage: String? = nil,
        savedAt: Date = .now
    ) {
        self.init(
            recent: RecentSearch(result: result, savedAt: savedAt),
            role: role,
            systemImage: systemImage
        )
    }

    init(recent: RecentSearch, role: Role, systemImage: String? = nil) {
        id = recent.id
        kind = recent.kind
        name = recent.name
        context = recent.context
        coordinate = recent.coordinate
        self.role = role
        self.systemImage = systemImage ?? role.systemImage
        savedAt = recent.savedAt
        updatedAt = recent.savedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        kind = try container.decode(RecentSearch.Kind.self, forKey: .kind)
        name = try container.decode(String.self, forKey: .name)
        context = try container.decodeIfPresent(String.self, forKey: .context)
        coordinate = try container.decode(GeoCoordinate.self, forKey: .coordinate)
        role = try container.decode(Role.self, forKey: .role)
        systemImage = try container.decodeIfPresent(String.self, forKey: .systemImage)
            ?? role.systemImage
        savedAt = try container.decode(Date.self, forKey: .savedAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
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


    private enum CodingKeys: String, CodingKey {
        case id, kind, name, context, coordinate, role, systemImage, savedAt, updatedAt
    }
}

struct SavedDestination: Codable, Sendable, Hashable, Identifiable {
    let id: UUID
    let destinationID: String
    let kind: RecentSearch.Kind
    let name: String
    let context: String?
    let coordinate: GeoCoordinate
    var label: String
    var systemImage: String
    var position: Int
    let savedAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        result: SearchResult,
        label: String,
        systemImage: String,
        position: Int,
        savedAt: Date = .now
    ) {
        let recent = RecentSearch(result: result, savedAt: savedAt)
        self.id = id
        destinationID = recent.id
        kind = recent.kind
        name = recent.name
        context = recent.context
        coordinate = recent.coordinate
        self.label = label
        self.systemImage = systemImage
        self.position = position
        self.savedAt = savedAt
        updatedAt = savedAt
    }

    init(
        replacing destination: SavedDestination,
        result: SearchResult,
        label: String,
        systemImage: String,
        updatedAt: Date
    ) {
        let recent = RecentSearch(result: result, savedAt: destination.savedAt)
        id = destination.id
        destinationID = recent.id
        kind = recent.kind
        name = recent.name
        context = recent.context
        coordinate = recent.coordinate
        self.label = label
        self.systemImage = systemImage
        position = destination.position
        savedAt = destination.savedAt
        self.updatedAt = updatedAt
    }

    var searchResult: SearchResult {
        RecentSearch(
            id: destinationID,
            kind: kind,
            name: name,
            context: context,
            coordinate: coordinate,
            savedAt: savedAt
        ).searchResult
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case destinationID = "destinationId"
        case kind, name, context, coordinate, label, systemImage, position, savedAt, updatedAt
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

enum NotificationCategory: String, Codable, Sendable, Hashable, CaseIterable, Identifiable {
    case journey, commute, line, station, digest, recommendation

    var id: String { rawValue }

    var title: String {
        switch self {
        case .journey: "Trajets actifs"
        case .commute: "Rappels récurrents"
        case .line: "Lignes suivies"
        case .station: "Stations suivies"
        case .digest: "Résumé quotidien"
        case .recommendation: "Suggestions"
        }
    }

    var systemImage: String {
        switch self {
        case .journey: "figure.walk"
        case .commute: "calendar.badge.clock"
        case .line: "tram.fill"
        case .station: "mappin.and.ellipse"
        case .digest: "text.badge.checkmark"
        case .recommendation: "sparkles"
        }
    }
}

enum NotificationSeverity: String, Codable, Sendable, Hashable, CaseIterable, Identifiable {
    case attention, disrupted, suspended

    var id: String { rawValue }

    var title: String {
        switch self {
        case .attention: "Attention"
        case .disrupted: "Perturbée"
        case .suspended: "Suspendue"
        }
    }
}

struct NotificationCategoryPreference: Codable, Sendable, Hashable, Identifiable {
    var category: NotificationCategory
    var enabled: Bool
    var minimumSeverity: NotificationSeverity
    var dailyCap: Int?

    var id: NotificationCategory { category }
}

struct NotificationPreferences: Codable, Sendable, Hashable {
    var enabled: Bool = true
    var timeZone: String = "Europe/Paris"
    var quietHoursStartMinute: Int?
    var quietHoursEndMinute: Int?
    var mutedOnWeekends: Bool = false
    var mutedOnHolidays: Bool = false
    var minimumSeverity: NotificationSeverity = .attention
    var dailyCap: Int?
    var categories: [NotificationCategoryPreference] = NotificationCategory.allCases.map {
        NotificationCategoryPreference(category: $0, enabled: true, minimumSeverity: .attention, dailyCap: nil)
    }
    var updatedAt: Date = .distantPast

    static let `default` = NotificationPreferences()
}

struct NotificationLocation: Codable, Sendable, Hashable {
    var id: String
    var kind: RecentSearch.Kind
    var name: String
    var context: String?
    var latitude: Double
    var longitude: Double
}

struct NotificationTimeWindow: Codable, Sendable, Hashable, Identifiable {
    var startMinute: Int
    var endMinute: Int

    var id: String { "\(startMinute)-\(endMinute)" }
}

struct NotificationSchedule: Codable, Sendable, Hashable, Identifiable {
    enum Kind: String, Codable, Sendable, Hashable, CaseIterable, Identifiable {
        case commute, digest
        var id: String { rawValue }
    }

    var id: String
    var kind: Kind
    var label: String
    var revision: Int
    var origin: NotificationLocation?
    var destination: NotificationLocation?
    var routeIDs: [String]
    var daysOfWeek: [Int]
    var departureMinute: Int
    var leadMinutes: Int
    var skipHolidays: Bool
    var enabled: Bool
    var pausedUntil: Date?
    var timeZone: String
    var savedAt: Date
    var updatedAt: Date
    var deletedAt: Date?

    private enum CodingKeys: String, CodingKey {
        case id, kind, label, revision, origin, destination
        case routeIDs = "routeIds"
        case daysOfWeek, departureMinute, leadMinutes, skipHolidays, enabled
        case pausedUntil, timeZone, savedAt, updatedAt, deletedAt
    }
}

struct NotificationAlertSubscription: Codable, Sendable, Hashable, Identifiable {
    enum TopicKind: String, Codable, Sendable, Hashable, CaseIterable, Identifiable {
        case line, station
        var id: String { rawValue }
    }

    var id: String
    var topicKind: TopicKind
    var topicID: String
    var label: String
    var daysOfWeek: [Int]
    var windows: [NotificationTimeWindow]
    var minimumSeverity: NotificationSeverity
    var enabled: Bool
    var savedAt: Date
    var updatedAt: Date
    var deletedAt: Date?

    private enum CodingKeys: String, CodingKey {
        case id, topicKind
        case topicID = "topicId"
        case label, daysOfWeek, windows, minimumSeverity, enabled, savedAt, updatedAt, deletedAt
    }
}

enum AccountScope: Codable, Sendable, Hashable, Equatable {
    case anonymous
    case user(String)

    var userID: String? {
        guard case .user(let userID) = self else { return nil }
        return userID
    }
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
        case destinationUpsert = "destination.upsert"
        case destinationRemove = "destination.remove"
        case notificationPreferencesSet = "notifications.preferences.set"
        case notificationScheduleUpsert = "notifications.schedule.upsert"
        case notificationScheduleRemove = "notifications.schedule.remove"
        case notificationAlertUpsert = "notifications.alert.upsert"
        case notificationAlertRemove = "notifications.alert.remove"
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
    let destination: SavedDestination?
    let destinationID: UUID?
    let notificationPreferences: NotificationPreferences?
    let schedule: NotificationSchedule?
    let scheduleID: String?
    let alertSubscription: NotificationAlertSubscription?
    let alertSubscriptionID: String?

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
        placeID: String? = nil,
        destination: SavedDestination? = nil,
        destinationID: UUID? = nil,
        notificationPreferences: NotificationPreferences? = nil,
        schedule: NotificationSchedule? = nil,
        scheduleID: String? = nil,
        alertSubscription: NotificationAlertSubscription? = nil,
        alertSubscriptionID: String? = nil
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
        self.destination = destination
        self.destinationID = destinationID
        self.notificationPreferences = notificationPreferences
        self.schedule = schedule
        self.scheduleID = scheduleID
        self.alertSubscription = alertSubscription
        self.alertSubscriptionID = alertSubscriptionID
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
        case destination
        case destinationID = "destinationId"
        case notificationPreferences
        case schedule
        case scheduleID = "scheduleId"
        case alertSubscription
        case alertSubscriptionID = "alertSubscriptionId"
    }
}

struct AccountSyncResult: Codable, Sendable, Hashable {
    let appliedOperationIDs: [UUID]
    let favorites: [FavoriteStation]
    let recents: [RecentSearch]
    let places: [SavedPlace]
    let destinations: [SavedDestination]
    let preferences: TransportPreferences
    let notificationPreferences: NotificationPreferences
    let notificationSchedules: [NotificationSchedule]
    let notificationAlerts: [NotificationAlertSubscription]
    let syncedAt: Date

    init(
        appliedOperationIDs: [UUID],
        favorites: [FavoriteStation],
        recents: [RecentSearch],
        places: [SavedPlace] = [],
        destinations: [SavedDestination] = [],
        preferences: TransportPreferences,
        notificationPreferences: NotificationPreferences = .default,
        notificationSchedules: [NotificationSchedule] = [],
        notificationAlerts: [NotificationAlertSubscription] = [],
        syncedAt: Date
    ) {
        self.appliedOperationIDs = appliedOperationIDs
        self.favorites = favorites
        self.recents = recents
        self.places = places
        self.destinations = destinations
        self.preferences = preferences
        self.notificationPreferences = notificationPreferences
        self.notificationSchedules = notificationSchedules
        self.notificationAlerts = notificationAlerts
        self.syncedAt = syncedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        appliedOperationIDs = try container.decode([UUID].self, forKey: .appliedOperationIDs)
        favorites = try container.decode([FavoriteStation].self, forKey: .favorites)
        recents = try container.decode([RecentSearch].self, forKey: .recents)
        // Tolerates a server that predates saved places.
        places = try container.decodeIfPresent([SavedPlace].self, forKey: .places) ?? []
        destinations = try container.decodeIfPresent([SavedDestination].self, forKey: .destinations) ?? []
        preferences = try container.decode(TransportPreferences.self, forKey: .preferences)
        notificationPreferences = try container.decodeIfPresent(NotificationPreferences.self, forKey: .notificationPreferences) ?? .default
        notificationSchedules = try container.decodeIfPresent([NotificationSchedule].self, forKey: .notificationSchedules) ?? []
        notificationAlerts = try container.decodeIfPresent([NotificationAlertSubscription].self, forKey: .notificationAlerts) ?? []
        syncedAt = try container.decode(Date.self, forKey: .syncedAt)
    }

    private enum CodingKeys: String, CodingKey {
        case appliedOperationIDs = "appliedOperationIds"
        case favorites
        case recents
        case places
        case destinations
        case preferences
        case notificationPreferences
        case notificationSchedules
        case notificationAlerts
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
    var places: [SavedPlace]
    var destinations: [SavedDestination] = []
    var transportPreferences: TransportPreferences
    var notificationPreferences: NotificationPreferences
    var notificationSchedules: [NotificationSchedule]
    var notificationAlerts: [NotificationAlertSubscription]

    static let empty = AccountSnapshot(
        favorites: [],
        places: [],
        destinations: [],
        transportPreferences: .empty,
        notificationPreferences: .default,
        notificationSchedules: [],
        notificationAlerts: []
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
    case local(AccountSnapshot)
    case active(AccountSnapshot, AccountSyncState)
}

struct AccountLocalSnapshot: Codable, Sendable, Hashable {
    /// Mirrors the server's `ACCOUNT_FAVORITE_LIMIT`; both sides trim to it.
    static let favoriteLimit = 50
    static let destinationLimit = 50
    var favorites: [FavoriteStation] = []
    var places: [SavedPlace] = []
    var destinations: [SavedDestination] = []
    var preferences: TransportPreferences = .empty
    var notificationPreferences: NotificationPreferences = .default
    var notificationSchedules: [NotificationSchedule] = []
    var notificationAlerts: [NotificationAlertSubscription] = []
    var pendingOperations: [AccountSyncOperation] = []
}
