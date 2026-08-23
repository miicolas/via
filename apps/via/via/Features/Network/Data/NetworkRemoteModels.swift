import Foundation

struct NetworkSegmentDTO: Decodable {
    let id: String
    let coordinates: [CoordinateDTO]
}

struct NetworkRouteDTO: Decodable {
    let id: String
    let shortName: String
    let mode: String
    let color: String
    let textColor: String
    let segments: [NetworkSegmentDTO]
}

struct NetworkStationDTO: Decodable {
    struct Accessibility: Decodable {
        let condition: String
        let label: String
        let comment: String?
    }

    struct Toilets: Decodable {
        let label: String
        let detail: String?
    }

    let id: String
    let name: String
    let coordinate: CoordinateDTO
    let routeIds: [String]
    let accessibility: Accessibility?
    let toilets: Toilets?

    func domain() -> NetworkStation {
        NetworkStation(
            id: StationID(rawValue: id),
            name: name,
            coordinate: coordinate.domain,
            routeIDs: routeIds.map(RouteID.init(rawValue:)),
            accessibility: accessibility.flatMap { value in
                guard let condition = StationAccessibility.Condition(rawValue: value.condition) else {
                    return nil
                }
                return StationAccessibility(
                    condition: condition,
                    label: value.label,
                    comment: value.comment
                )
            },
            toilets: toilets.map { StationToilets(label: $0.label, detail: $0.detail) }
        )
    }
}

struct RailMapDTO: Decodable {
    let routes: [NetworkRouteDTO]
    let stations: [NetworkStationDTO]

    func domain() throws -> TransitNetwork {
        TransitNetwork(
            routes: try routes.map { route in
                let badge = try RouteBadgeDTO(
                    id: route.id,
                    shortName: route.shortName,
                    mode: route.mode,
                    color: route.color,
                    textColor: route.textColor
                ).domain()
                return NetworkRoute(
                    badge: badge,
                    segments: route.segments.map {
                        NetworkSegment(id: $0.id, coordinates: $0.coordinates.map(\.domain))
                    }
                )
            },
            stations: stations.map { $0.domain() }
        )
    }
}

struct StationsAreaDTO: Decodable {
    let stations: [NetworkStationDTO]
    let routes: [RouteBadgeDTO]

    func domain() throws -> StationsArea {
        StationsArea(
            stations: stations.map { $0.domain() },
            routes: try routes.map { try $0.domain() }
        )
    }
}
