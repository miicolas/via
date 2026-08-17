import Foundation

/// The nested destination shape carried by JSON response bodies (natural
/// journeys). The GET /journeys query flattens it instead — deepObject
/// serialization cannot express nesting; see `LiveJourneyRepository`.
enum JourneyDestinationDTO: Decodable {
    case station(Station)
    case address(Address)

    struct Station: Decodable {
        let id: String
        let name: String
        let coordinate: CoordinateDTO
    }

    struct Address: Decodable {
        let id: String
        let name: String
        let context: String?
        let coordinate: CoordinateDTO
    }

    private enum CodingKeys: String, CodingKey { case kind }

    init(from decoder: Decoder) throws {
        let kind = try decoder.container(keyedBy: CodingKeys.self).decode(
            String.self,
            forKey: .kind
        )
        let single = try decoder.singleValueContainer()
        switch kind {
        case "station": self = .station(try single.decode(Station.self))
        case "address": self = .address(try single.decode(Address.self))
        default:
            throw DecodingError.dataCorruptedError(
                in: single,
                debugDescription: "Unknown destination: \(kind)"
            )
        }
    }

    var domain: JourneyDestination {
        switch self {
        case .station(let value):
            .station(
                id: .init(rawValue: value.id),
                name: value.name,
                coordinate: value.coordinate.domain
            )
        case .address(let value):
            .address(
                id: value.id,
                name: value.name,
                context: value.context,
                coordinate: value.coordinate.domain
            )
        }
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

        func domain() throws -> Journey {
            guard
                let qualifier = Journey.Qualifier(rawValue: qualifier),
                let status = Journey.Status(rawValue: status)
            else { throw ViaError.decoding }
            return Journey(
                id: JourneyID(rawValue: id),
                qualifier: qualifier,
                durationSeconds: durationSeconds,
                walkingDurationSeconds: walkingDurationSeconds,
                transferCount: transferCount,
                departureAt: departureAt,
                arrivalAt: arrivalAt,
                status: status,
                warnings: warnings,
                sections: try sections.enumerated().map { index, section in
                    try section.domain(id: "\(id):\(index)")
                }
            )
        }
    }

    struct PlaceDTO: Decodable {
        let name: String
        let coordinate: CoordinateDTO
    }

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

        func domain(id: String) throws -> JourneySection {
            guard let kind = JourneySection.Kind(rawValue: type) else {
                throw ViaError.decoding
            }
            let mappedRoute = try route.map { value in
                guard let mode = TransitMode(rawValue: value.mode) else {
                    throw ViaError.decoding
                }
                return JourneyRoute(
                    id: RouteID(rawValue: value.id),
                    shortName: value.shortName,
                    longName: value.longName,
                    mode: mode,
                    colorHex: value.color,
                    textColorHex: value.textColor
                )
            }
            return JourneySection(
                id: id,
                kind: kind,
                durationSeconds: durationSeconds,
                from: JourneyPlace(name: from.name, coordinate: from.coordinate.domain),
                to: JourneyPlace(name: to.name, coordinate: to.coordinate.domain),
                departureAt: departureAt,
                arrivalAt: arrivalAt,
                geometry: geometry.map(\.domain),
                route: mappedRoute,
                direction: direction,
                platform: platform,
                stops: stops.map {
                    JourneyStop(
                        id: $0.id,
                        name: $0.name,
                        coordinate: $0.coordinate.domain,
                        arrivalAt: $0.arrivalAt,
                        departureAt: $0.departureAt
                    )
                }
            )
        }
    }

    let status: String
    let source: String?
    let generatedAt: Date
    let journeys: [JourneyDTO]

    func domain() throws -> JourneyResult {
        guard let status = JourneyResult.Status(rawValue: status) else {
            throw ViaError.decoding
        }
        let mappedSource = try source.map { value in
            guard let result = JourneyResult.Source(rawValue: value) else {
                throw ViaError.decoding
            }
            return result
        }
        return JourneyResult(
            status: status,
            source: mappedSource,
            generatedAt: generatedAt,
            journeys: try journeys.map { try $0.domain() }
        )
    }
}
