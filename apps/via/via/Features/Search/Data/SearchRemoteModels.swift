import Foundation

struct SearchResponseDTO: Decodable {
    struct Sources: Decodable {
        struct Accessibility: Decodable {
            let status: String
            let sourceUpdatedAt: Date?
            let importedAt: Date?
        }

        let ban: String
        let accessibility: Accessibility?
        let elevators: Accessibility?
        let velib: String?
    }
    let results: [SearchResultDTO]
    let sources: Sources

    func domain() throws -> SearchResponse {
        SearchResponse(
            results: try results.map { try $0.domain() },
            addressSource: sources.ban == "ok" ? .ok : .unavailable,
            accessibilitySource: .init(
                status: sources.accessibility?.status == "ok" ? .ok : .unavailable,
                sourceUpdatedAt: sources.accessibility?.sourceUpdatedAt,
                importedAt: sources.accessibility?.importedAt
            ),
            elevatorSource: .init(
                status: sources.elevators?.status == "ok" ? .ok : .unavailable,
                sourceUpdatedAt: sources.elevators?.sourceUpdatedAt,
                importedAt: sources.elevators?.importedAt
            ),
            bikeSource: sources.velib == "ok" ? .ok : .unavailable
        )
    }
}

enum SearchResultDTO: Codable {
    case station(Station)
    case address(Address)
    case bikeStation(BikeStation)

    struct Station: Codable {
        let id: String
        let name: String
        let coordinate: CoordinateDTO
        let routes: [RouteBadgeDTO]
        let distanceMeters: Double?
        let accessibility: Accessibility?

        struct Accessibility: Codable {
            let condition: String
            let label: String
            let comment: String?
        }
    }

    struct Address: Codable {
        let id: String
        let name: String
        let context: String
        let coordinate: CoordinateDTO
        let distanceMeters: Double?
    }

    struct BikeStation: Codable {
        let id: String
        let name: String
        let coordinate: CoordinateDTO
        let distanceMeters: Double?
        let capacity: Int
        let availability: BikeStationAvailability?
    }

    private enum CodingKeys: String, CodingKey { case kind }

    init(_ value: SearchResult) {
        switch value {
        case .station(let station):
            self = .station(.init(
                id: station.id.rawValue,
                name: station.name,
                coordinate: .init(station.coordinate),
                routes: station.routes.map(RouteBadgeDTO.init),
                distanceMeters: station.distanceMeters,
                accessibility: station.accessibility.flatMap { value in
                    guard let condition = StationAccessibility.Condition(rawValue: value.condition.rawValue) else {
                        return nil
                    }
                    return Station.Accessibility(
                        condition: condition.rawValue,
                        label: value.label,
                        comment: value.comment
                    )
                }
            ))
        case .address(let address):
            self = .address(.init(
                id: address.id,
                name: address.name,
                context: address.context,
                coordinate: .init(address.coordinate),
                distanceMeters: address.distanceMeters
            ))
        case .bikeStation(let bike):
            self = .bikeStation(.init(
                id: bike.id,
                name: bike.name,
                coordinate: .init(bike.coordinate),
                distanceMeters: bike.distanceMeters,
                capacity: bike.capacity,
                availability: bike.availability
            ))
        }
    }

    init(from decoder: Decoder) throws {
        let kind = try decoder.container(keyedBy: CodingKeys.self).decode(
            String.self,
            forKey: .kind
        )
        let container = try decoder.singleValueContainer()
        switch kind {
        case "station": self = .station(try container.decode(Station.self))
        case "address": self = .address(try container.decode(Address.self))
        case "bikeStation": self = .bikeStation(try container.decode(BikeStation.self))
        default:
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unknown search result: \(kind)"
            )
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
        case .bikeStation(let value):
            kind = "bikeStation"
            try value.encode(to: encoder)
        }
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(kind, forKey: .kind)
    }

    func domain() throws -> SearchResult {
        switch self {
        case .station(let value):
            .station(StationSearchResult(
                id: StationID(rawValue: value.id),
                name: value.name,
                coordinate: value.coordinate.domain,
                routes: try value.routes.map { try $0.domain() },
                distanceMeters: value.distanceMeters,
                accessibility: value.accessibility.flatMap { accessibility in
                    guard let condition = StationAccessibility.Condition(rawValue: accessibility.condition) else {
                        return nil
                    }
                    return StationAccessibility(
                        condition: condition,
                        label: accessibility.label,
                        comment: accessibility.comment
                    )
                }
            ))
        case .address(let value):
            .address(AddressSearchResult(
                id: value.id,
                name: value.name,
                context: value.context,
                coordinate: value.coordinate.domain,
                distanceMeters: value.distanceMeters
            ))
        case .bikeStation(let value):
            .bikeStation(BikeStationSearchResult(
                id: value.id,
                name: value.name,
                coordinate: value.coordinate.domain,
                distanceMeters: value.distanceMeters,
                capacity: value.capacity,
                availability: value.availability
            ))
        }
    }
}
