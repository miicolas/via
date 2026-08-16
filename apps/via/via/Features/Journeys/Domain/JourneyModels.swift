import Foundation

enum JourneyDestination: Sendable, Hashable {
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
}

struct JourneyPlace: Sendable, Hashable {
    let name: String
    let coordinate: GeoCoordinate
}

struct JourneyStop: Sendable, Hashable, Identifiable {
    let id: String
    let name: String
    let coordinate: GeoCoordinate
    let arrivalAt: Date?
    let departureAt: Date?
}

struct JourneyRoute: Sendable, Hashable, Identifiable {
    let id: RouteID
    let shortName: String
    let longName: String
    let mode: TransitMode
    let colorHex: String
    let textColorHex: String
}

struct JourneySection: Sendable, Hashable, Identifiable {
    enum Kind: String, Sendable, Hashable { case walk, wait, transfer, transit }

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

struct Journey: Sendable, Hashable, Identifiable {
    enum Qualifier: String, Sendable, Hashable {
        case recommended
        case rapid
        case lessWalking = "less-walking"
        case comfort
        case walking
    }

    enum Status: String, Sendable, Hashable { case normal, disrupted, theoretical }

    let id: JourneyID
    let qualifier: Qualifier
    let durationSeconds: Int
    let walkingDurationSeconds: Int
    let transferCount: Int
    let departureAt: Date
    let arrivalAt: Date
    let status: Status
    let warnings: [String]
    let sections: [JourneySection]
}

struct JourneyResult: Sendable, Hashable {
    enum Status: String, Sendable, Hashable { case ready, noRoute = "no-route", unavailable }
    enum Source: String, Sendable, Hashable { case realtime = "idfm-realtime", theoretical = "gtfs-theoretical" }

    let status: Status
    let source: Source?
    let generatedAt: Date
    let journeys: [Journey]
}

