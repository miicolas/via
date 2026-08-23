import Foundation

enum ReportCategoryGroup: String, CaseIterable, Codable, Sendable, Hashable {
    case safetyAndCrowding
    case accessibilityAndEquipment
    case accessAndService

    var categories: [ReportCategory] {
        ReportCategory.allCases.filter { $0.group == self }
    }
}

enum ReportCategory: String, CaseIterable, Codable, Sendable, Hashable {
    case pickpocket
    case crowding
    case restroomsClosed
    case ticketMachinesUnavailable
    case wheelchairAccessUnavailable
    case elevatorsUnavailable
    case escalatorUnavailable
    case validatorsUnavailable
    case entranceOrExitClosed
    case stopRelocated
    case stopNotServed
    case passengerInformationUnavailable
    case passageObstructed

    var group: ReportCategoryGroup {
        switch self {
        case .pickpocket, .crowding:
            .safetyAndCrowding
        case .restroomsClosed,
             .ticketMachinesUnavailable,
             .wheelchairAccessUnavailable,
             .elevatorsUnavailable,
             .escalatorUnavailable,
             .validatorsUnavailable:
            .accessibilityAndEquipment
        case .entranceOrExitClosed,
             .stopRelocated,
             .stopNotServed,
             .passengerInformationUnavailable,
             .passageObstructed:
            .accessAndService
        }
    }
}

enum CrowdingLevel: String, CaseIterable, Codable, Sendable, Hashable {
    case low
    case moderate
    case high
    case saturated

    var title: String {
        switch self {
        case .low: "Faible"
        case .moderate: "Modérée"
        case .high: "Forte"
        case .saturated: "Saturée"
        }
    }

    var explanation: String {
        switch self {
        case .low:
            "Circulation fluide, beaucoup d’espace."
        case .moderate:
            "Présence notable, mais déplacements faciles."
        case .high:
            "Espace serré et déplacements difficiles."
        case .saturated:
            "Accès ou embarquement difficile, voire impossible."
        }
    }
}

enum ReportValue: Codable, Sendable, Hashable {
    case occurrence
    case resolved
    case crowding(CrowdingLevel)
}

enum ReportDataSource: String, Codable, Sendable, Hashable {
    case automatic
    case reported
}

enum ReportIncidentState: String, Codable, Sendable, Hashable {
    case active
    case recovered
}

/// Both closed sets come from the wire contract; decoding one keeps them closed here.
enum LiveAvailability: String, Codable, Sendable, Hashable {
    case available
    case unavailable
}

enum ReportConfidence: String, Codable, Sendable, Hashable {
    case observed
    case confirmed
}

enum ReportScopeKind: String, Codable, Sendable, Hashable {
    case station
    case line
    case vehicle
}

struct LiveAccessibilityStatus: Codable, Sendable, Hashable {
    let state: LiveAvailability
    let source: ReportDataSource
    let condition: AccessibilityCondition?
    let label: String
    let reporterCount: Int?
    let observedAt: Date?
    let expiresAt: Date?
    let confidence: ReportConfidence?
}

struct LiveCrowdingStatus: Codable, Sendable, Hashable {
    let level: CrowdingLevel
    let source: ReportDataSource
    let label: String
    let reporterCount: Int?
    let observedAt: Date?
    let expiresAt: Date?
}

struct LiveReportIncident: Codable, Sendable, Hashable, Identifiable {
    let category: ReportCategory
    let scopeKind: ReportScopeKind
    let scopeId: String
    let state: ReportIncidentState
    let label: String
    let reporterCount: Int
    let observedAt: Date
    let expiresAt: Date

    var id: String { "\(category.rawValue):\(scopeKind.rawValue):\(scopeId):\(state.rawValue)" }
    var canReportRecovery: Bool { category != .pickpocket && state == .active }
}

struct StationLiveStatus: Codable, Sendable, Hashable {
    let stationId: String
    let generatedAt: Date
    let accessibility: LiveAccessibilityStatus?
    let crowding: LiveCrowdingStatus?
    let incidents: [LiveReportIncident]
    let wheelchairRouteExcluded: Bool

    static func empty(stationID: StationID, at: Date = .now) -> Self {
        .init(
            stationId: stationID.rawValue,
            generatedAt: at,
            accessibility: nil,
            crowding: nil,
            incidents: [],
            wheelchairRouteExcluded: false
        )
    }

    /// Whether anything here is still worth showing at `date`. Freshness is the
    /// data's own rule, not a screen's: an automatic datum is the station's
    /// usual state and never goes stale, a reported one lives until it expires.
    func hasActiveContent(at date: Date) -> Bool {
        accessibility?.isActive(at: date) == true
            || crowding?.isActive(at: date) == true
            || incidents.contains { $0.isActive(at: date) }
    }
}

extension LiveAccessibilityStatus {
    func isActive(at date: Date) -> Bool {
        source == .automatic || (expiresAt.map { $0 > date } ?? false)
    }
}

extension LiveCrowdingStatus {
    func isActive(at date: Date) -> Bool {
        source == .automatic || (expiresAt.map { $0 > date } ?? false)
    }
}

extension LiveReportIncident {
    func isActive(at date: Date) -> Bool { expiresAt > date }
}

struct ReportStation: Codable, Sendable, Hashable, Identifiable {
    let id: StationID
    let name: String
    let coordinate: GeoCoordinate
    let routes: [RouteBadge]

    init(
        id: StationID,
        name: String,
        coordinate: GeoCoordinate,
        routes: [RouteBadge] = []
    ) {
        self.id = id
        self.name = name
        self.coordinate = coordinate
        self.routes = routes
    }

    init(networkStation: NetworkStation, routes: [RouteBadge]) {
        self.init(
            id: networkStation.id,
            name: networkStation.name,
            coordinate: networkStation.coordinate,
            routes: routes
        )
    }

    init(searchResult: StationSearchResult) {
        self.init(
            id: searchResult.id,
            name: searchResult.name,
            coordinate: searchResult.coordinate,
            routes: searchResult.routes
        )
    }
}

struct ReportContext: Codable, Sendable, Hashable {
    let coordinate: GeoCoordinate
    let station: ReportStation
    let lineID: RouteID?
    let journeyID: JourneyID?
    let vehicleID: String?

    init(
        coordinate: GeoCoordinate,
        station: ReportStation,
        lineID: RouteID? = nil,
        journeyID: JourneyID? = nil,
        vehicleID: String? = nil
    ) {
        self.coordinate = coordinate.roundedForReport
        self.station = station
        self.lineID = lineID
        self.journeyID = journeyID
        self.vehicleID = vehicleID
    }
}

struct ReportSubmission: Codable, Sendable, Hashable, Identifiable {
    let id: UUID
    let category: ReportCategory
    let value: ReportValue
    let context: ReportContext
    let submittedAt: Date

    init(
        id: UUID = UUID(),
        category: ReportCategory,
        value: ReportValue,
        context: ReportContext,
        submittedAt: Date = .now
    ) {
        self.id = id
        self.category = category
        self.value = value
        self.context = context
        self.submittedAt = submittedAt
    }
}

private extension GeoCoordinate {
    var roundedForReport: GeoCoordinate {
        GeoCoordinate(
            latitude: (latitude * 10_000).rounded() / 10_000,
            longitude: (longitude * 10_000).rounded() / 10_000
        )
    }
}
