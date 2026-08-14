import Foundation

struct JourneyDestination: Codable, Hashable, Identifiable, Sendable {
    enum Kind: String, Codable, Hashable, Sendable {
        case station
        case address
    }

    let kind: Kind
    let id: String
    let name: String
    let context: String?
    let coordinate: GeoCoordinate

    init(
        kind: Kind,
        id: String,
        name: String,
        context: String? = nil,
        coordinate: GeoCoordinate
    ) {
        self.kind = kind
        self.id = id
        self.name = name
        self.context = context
        self.coordinate = coordinate
    }

    init?(searchResult: SearchResult) {
        switch searchResult {
        case .station(let result):
            kind = .station
            id = result.id
            name = result.name
            context = nil
            coordinate = result.coordinate
        case .address(let result):
            kind = .address
            id = result.id
            name = result.name
            context = result.context
            coordinate = result.coordinate
        }
    }

    init(station: NetworkStation) {
        kind = .station
        id = station.id
        name = station.name
        context = nil
        coordinate = station.coordinate
    }
}

struct JourneyRequest: Hashable, Sendable {
    let origin: GeoCoordinate
    let destination: JourneyDestination
    let limit: Int

    init(origin: GeoCoordinate, destination: JourneyDestination, limit: Int = 4) {
        self.origin = origin
        self.destination = destination
        self.limit = min(max(limit, 1), 6)
    }

    var key: String {
        [
            origin.latitude.formatted(.number.precision(.fractionLength(5))),
            origin.longitude.formatted(.number.precision(.fractionLength(5))),
            destination.kind.rawValue,
            destination.id,
            destination.coordinate.latitude.formatted(.number.precision(.fractionLength(5))),
            destination.coordinate.longitude.formatted(.number.precision(.fractionLength(5))),
            String(limit),
        ].joined(separator: ":")
    }
}

enum JourneyState: Equatable, Sendable {
    case idle
    case planning(request: JourneyRequest)
    case ready(request: JourneyRequest, response: JourneysResponse)
    case failed(request: JourneyRequest)

    var request: JourneyRequest? {
        switch self {
        case .idle: nil
        case .planning(let request), .ready(let request, _), .failed(let request): request
        }
    }

    var response: JourneysResponse? {
        if case .ready(_, let response) = self { return response }
        return nil
    }
}

enum JourneySectionType: String, Codable, Hashable, Sendable {
    case walk
    case wait
    case transfer
    case transit
}

enum JourneyQualifier: String, Codable, Hashable, Sendable {
    case recommended
    case rapid
    case lessWalking = "less-walking"
    case comfort
    case walking
}

enum JourneyStatus: String, Codable, Hashable, Sendable {
    case normal
    case disrupted
    case theoretical
}

struct JourneyPlace: Codable, Hashable, Sendable {
    let name: String
    let coordinate: GeoCoordinate
}

struct JourneyStop: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let name: String
    let coordinate: GeoCoordinate
    let arrivalAt: String?
    let departureAt: String?
}

struct JourneyRoute: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let shortName: String
    let longName: String
    let mode: TransitMode
    let color: String
    let textColor: String
}

struct JourneySection: Codable, Hashable, Sendable {
    let type: JourneySectionType
    let durationSeconds: Int
    let from: JourneyPlace
    let to: JourneyPlace
    let departureAt: String?
    let arrivalAt: String?
    let geometry: [GeoCoordinate]
    let route: JourneyRoute?
    let direction: String?
    let platform: String?
    let stops: [JourneyStop]
}

struct Journey: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let qualifier: JourneyQualifier
    let durationSeconds: Int
    let walkingDurationSeconds: Int
    let transferCount: Int
    let departureAt: String
    let arrivalAt: String
    let status: JourneyStatus
    let warnings: [String]
    let sections: [JourneySection]
}

struct JourneysResponse: Codable, Hashable, Sendable {
    enum Status: String, Codable, Hashable, Sendable {
        case ready
        case noRoute = "no-route"
        case unavailable
    }

    enum Source: String, Codable, Hashable, Sendable {
        case idfmRealtime = "idfm-realtime"
        case gtfsTheoretical = "gtfs-theoretical"
    }

    let status: Status
    let source: Source?
    let generatedAt: String
    let journeys: [Journey]
}
