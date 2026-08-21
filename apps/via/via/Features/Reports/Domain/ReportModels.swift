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
    case crowding(CrowdingLevel)
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
