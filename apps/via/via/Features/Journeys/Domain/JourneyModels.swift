import Foundation

enum JourneyDestination: Codable, Sendable, Hashable {
    case station(id: StationID, name: String, coordinate: GeoCoordinate)
    case address(id: String, name: String, context: String?, coordinate: GeoCoordinate)

    var coordinate: GeoCoordinate {
        switch self {
        case .station(_, _, let coordinate), .address(_, _, _, let coordinate): coordinate
        }
    }

    var name: String {
        switch self {
        case .station(_, let name, _), .address(_, let name, _, _): name
        }
    }
}

enum JourneyDatetimeRepresents: String, Codable, Sendable, Hashable {
    case departure
    case arrival
}

struct JourneyRequest: Sendable, Hashable {
    let origin: GeoCoordinate
    let destination: JourneyDestination
    var limit = 4
    var requestedAt: Date?
    var datetimeRepresents: JourneyDatetimeRepresents?
    var requiredModes: Set<TransitMode> = []
    var excludedModes: Set<TransitMode> = []
    var preferredModes: Set<TransitMode> = []
    var requiresAccessibleStations = false
    var originStationID: StationID?
}

struct JourneyPlace: Codable, Sendable, Hashable {
    let name: String
    let coordinate: GeoCoordinate
}

struct JourneyStop: Codable, Sendable, Hashable, Identifiable {
    let id: String
    let name: String
    let coordinate: GeoCoordinate
    let arrivalAt: Date?
    let departureAt: Date?
}

struct JourneyRoute: Codable, Sendable, Hashable, Identifiable {
    let id: RouteID
    let shortName: String
    let longName: String
    let mode: TransitMode
    let colorHex: String
    let textColorHex: String
}

struct JourneySection: Codable, Sendable, Hashable, Identifiable {
    enum Kind: String, Codable, Sendable, Hashable { case walk, wait, transfer, transit }

    let id: String
    let kind: Kind
    let durationSeconds: Int
    let from: JourneyPlace
    let to: JourneyPlace
    let departureAt: Date?
    let arrivalAt: Date?
    let geometry: [GeoCoordinate]
    let route: JourneyRoute?
    let direction: String?
    let platform: String?
    let stops: [JourneyStop]
}

struct Journey: Codable, Sendable, Hashable, Identifiable {
    enum Qualifier: String, Codable, Sendable, Hashable {
        case recommended
        case rapid
        case lessWalking = "less-walking"
        case comfort
        case walking
    }

    enum Status: String, Codable, Sendable, Hashable { case normal, disrupted, theoretical }

    struct Accessibility: Codable, Sendable, Hashable {
        enum Condition: String, Codable, Sendable, Hashable {
            case reservationRequired
            case staffAssistance
            case autonomous
        }

        let condition: Condition
        let label: String
    }

    let id: JourneyID
    let qualifier: Qualifier
    let durationSeconds: Int
    let walkingDurationSeconds: Int
    let transferCount: Int
    let departureAt: Date
    let arrivalAt: Date
    let status: Status
    let warnings: [String]
    let accessibility: Accessibility?
    let sections: [JourneySection]

    init(
        id: JourneyID,
        qualifier: Qualifier,
        durationSeconds: Int,
        walkingDurationSeconds: Int,
        transferCount: Int,
        departureAt: Date,
        arrivalAt: Date,
        status: Status,
        warnings: [String],
        accessibility: Accessibility? = nil,
        sections: [JourneySection]
    ) {
        self.id = id
        self.qualifier = qualifier
        self.durationSeconds = durationSeconds
        self.walkingDurationSeconds = walkingDurationSeconds
        self.transferCount = transferCount
        self.departureAt = departureAt
        self.arrivalAt = arrivalAt
        self.status = status
        self.warnings = warnings
        self.accessibility = accessibility
        self.sections = sections
    }
}

struct JourneyResult: Sendable, Hashable {
    enum Status: String, Sendable, Hashable { case ready, noRoute = "no-route", unavailable }
    enum Source: String, Codable, Sendable, Hashable { case realtime = "idfm-realtime", theoretical = "gtfs-theoretical" }
    enum Reason: String, Sendable, Hashable {
        case noAccessibleRoute = "no-accessible-route"
        case accessibilityDataUnavailable = "accessibility-data-unavailable"
    }

    let status: Status
    let source: Source?
    let generatedAt: Date
    let journeys: [Journey]
    let reason: Reason?

    init(
        status: Status,
        source: Source?,
        generatedAt: Date,
        journeys: [Journey],
        reason: Reason? = nil
    ) {
        self.status = status
        self.source = source
        self.generatedAt = generatedAt
        self.journeys = journeys
        self.reason = reason
    }
}
