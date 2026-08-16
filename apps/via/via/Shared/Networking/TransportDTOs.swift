import Foundation

struct CoordinateDTO: Codable { let latitude: Double; let longitude: Double }

struct RouteBadgeDTO: Codable {
    let id: String
    let shortName: String
    let mode: String
    let color: String
    let textColor: String
}

struct NetworkSegmentDTO: Decodable { let id: String; let coordinates: [CoordinateDTO] }
struct NetworkRouteDTO: Decodable {
    let id: String
    let shortName: String
    let mode: String
    let color: String
    let textColor: String
    let segments: [NetworkSegmentDTO]
}
struct NetworkStationDTO: Decodable { let id: String; let name: String; let coordinate: CoordinateDTO; let routeIds: [String] }
struct RailMapDTO: Decodable { let routes: [NetworkRouteDTO]; let stations: [NetworkStationDTO] }
struct StationsAreaDTO: Decodable { let stations: [NetworkStationDTO]; let routes: [RouteBadgeDTO] }

struct SearchResponseDTO: Decodable {
    struct Sources: Decodable { let ban: String }
    let results: [SearchResultDTO]
    let sources: Sources
}

enum SearchResultDTO: Codable {
    case station(Station)
    case address(Address)

    struct Station: Codable {
        let id: String
        let name: String
        let coordinate: CoordinateDTO
        let routes: [RouteBadgeDTO]
        let distanceMeters: Double?
    }
    struct Address: Codable {
        let id: String
        let name: String
        let context: String
        let coordinate: CoordinateDTO
        let distanceMeters: Double?
    }

    private enum CodingKeys: String, CodingKey { case kind }

    init(from decoder: Decoder) throws {
        let kind = try decoder.container(keyedBy: CodingKeys.self).decode(String.self, forKey: .kind)
        let container = try decoder.singleValueContainer()
        switch kind {
        case "station": self = .station(try container.decode(Station.self))
        case "address": self = .address(try container.decode(Address.self))
        default: throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unknown search result: \(kind)")
        }
    }

    func encode(to encoder: Encoder) throws {
        let kind: String
        switch self {
        case .station(let value):
            kind = "station"
            try value.encode(to: encoder)
        case .address(let value):
            kind = "address"
            try value.encode(to: encoder)
        }
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(kind, forKey: .kind)
    }
}

struct DepartureBoardDTO: Decodable {
    struct Group: Decodable {
        let route: RouteBadgeDTO
        let destination: String
        let departures: [Date]
    }
    let source: String
    let generatedAt: Date
    let groups: [Group]
}

enum JourneyDestinationDTO: Codable {
    case station(Station)
    case address(Address)

    struct Station: Codable { let id: String; let name: String; let coordinate: CoordinateDTO }
    struct Address: Codable { let id: String; let name: String; let context: String?; let coordinate: CoordinateDTO }
    private enum CodingKeys: String, CodingKey { case kind }

    init(from decoder: Decoder) throws {
        let kind = try decoder.container(keyedBy: CodingKeys.self).decode(String.self, forKey: .kind)
        let single = try decoder.singleValueContainer()
        switch kind {
        case "station": self = .station(try single.decode(Station.self))
        case "address": self = .address(try single.decode(Address.self))
        default: throw DecodingError.dataCorruptedError(in: single, debugDescription: "Unknown destination: \(kind)")
        }
    }

    func encode(to encoder: Encoder) throws {
        let kind: String
        switch self {
        case .station(let value):
            kind = "station"
            try value.encode(to: encoder)
        case .address(let value):
            kind = "address"
            try value.encode(to: encoder)
        }
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(kind, forKey: .kind)
    }
}

struct JourneyResultDTO: Decodable {
    struct JourneyDTO: Decodable {
        let id: String
        let qualifier: String
        let durationSeconds: Int
        let walkingDurationSeconds: Int
        let transferCount: Int
        let departureAt: Date
        let arrivalAt: Date
        let status: String
        let warnings: [String]
        let sections: [SectionDTO]
    }
    struct PlaceDTO: Decodable { let name: String; let coordinate: CoordinateDTO }
    struct StopDTO: Decodable {
        let id: String
        let name: String
        let coordinate: CoordinateDTO
        let arrivalAt: Date?
        let departureAt: Date?
    }
    struct RouteDTO: Decodable {
        let id: String
        let shortName: String
        let longName: String
        let mode: String
        let color: String
        let textColor: String
    }
    struct SectionDTO: Decodable {
        let type: String
        let durationSeconds: Int
        let from: PlaceDTO
        let to: PlaceDTO
        let departureAt: Date?
        let arrivalAt: Date?
        let geometry: [CoordinateDTO]
        let route: RouteDTO?
        let direction: String?
        let platform: String?
        let stops: [StopDTO]
    }
    let status: String
    let source: String?
    let generatedAt: Date
    let journeys: [JourneyDTO]
}

struct RouteIntentDTO: Codable {
    enum OriginDTO: Codable {
        case currentLocation
        case place(String)

        private enum CodingKeys: String, CodingKey { case kind, query }
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            switch try container.decode(String.self, forKey: .kind) {
            case "current_location": self = .currentLocation
            case "place": self = .place(try container.decode(String.self, forKey: .query))
            default: throw DecodingError.dataCorruptedError(forKey: .kind, in: container, debugDescription: "Unknown origin")
            }
        }
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .currentLocation: try container.encode("current_location", forKey: .kind)
            case .place(let query):
                try container.encode("place", forKey: .kind)
                try container.encode(query, forKey: .query)
            }
        }
    }
    let scope: String
    let origin: OriginDTO
    let destinationQuery: String?
    let requestedAt: Date?
    let datetimeRepresents: String
    let requiredModes: [String]
    let excludedModes: [String]
    let preferredModes: [String]
}

struct NaturalJourneyDraftDTO: Codable {
    let intent: RouteIntentDTO
    let origin: SearchResultDTO?
    let destination: SearchResultDTO?
}

enum NaturalJourneyRequestDTO: Encodable {
    case submit(query: String, location: CoordinateDTO?)
    case resolve(draft: NaturalJourneyDraftDTO, location: CoordinateDTO?, origin: SearchResultDTO?, destination: SearchResultDTO?, time: String?)

    private enum CodingKeys: String, CodingKey { case action, query, currentLocation, draft, origin, destination, datetimeRepresents }
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .submit(let query, let location):
            try container.encode("submit", forKey: .action)
            try container.encode(query, forKey: .query)
            try container.encodeIfPresent(location, forKey: .currentLocation)
        case .resolve(let draft, let location, let origin, let destination, let time):
            try container.encode("resolve", forKey: .action)
            try container.encode(draft, forKey: .draft)
            try container.encodeIfPresent(location, forKey: .currentLocation)
            try container.encodeIfPresent(origin, forKey: .origin)
            try container.encodeIfPresent(destination, forKey: .destination)
            try container.encodeIfPresent(time, forKey: .datetimeRepresents)
        }
    }
}

enum NaturalJourneyResultDTO: Decodable {
    struct Ready: Decodable {
        struct Interpretation: Decodable {
            let originLabel: String
            let destination: JourneyDestinationDTO
            let destinationResult: SearchResultDTO
            let requestedAt: Date
            let datetimeRepresents: String
            let requiredModes: [String]
            let excludedModes: [String]
            let preferredModes: [String]
        }
        let answer: String
        let preferenceNotice: String?
        let interpretation: Interpretation
        let journeys: JourneyResultDTO
    }
    struct Clarification: Decodable {
        struct Field: Decodable { let target: String; let question: String; let candidates: [SearchResultDTO] }
        let draft: NaturalJourneyDraftDTO
        let fields: [Field]
    }
    struct Message: Decodable { let message: String; let examples: [String]? }

    case ready(Ready)
    case clarification(Clarification)
    case unsupported(Message)
    case unavailable(Message)
    case rateLimited(Message)

    private enum CodingKeys: String, CodingKey { case status }
    init(from decoder: Decoder) throws {
        let status = try decoder.container(keyedBy: CodingKeys.self).decode(String.self, forKey: .status)
        let single = try decoder.singleValueContainer()
        switch status {
        case "ready": self = .ready(try single.decode(Ready.self))
        case "needs_clarification": self = .clarification(try single.decode(Clarification.self))
        case "unsupported": self = .unsupported(try single.decode(Message.self))
        case "unavailable": self = .unavailable(try single.decode(Message.self))
        case "rate_limited": self = .rateLimited(try single.decode(Message.self))
        default: throw DecodingError.dataCorruptedError(in: single, debugDescription: "Unknown natural result: \(status)")
        }
    }
}
