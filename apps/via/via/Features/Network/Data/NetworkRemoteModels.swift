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
    let id: String
    let name: String
    let coordinate: CoordinateDTO
    let routeIds: [String]

    func domain() -> NetworkStation {
        NetworkStation(
            id: StationID(rawValue: id),
            name: name,
            coordinate: coordinate.domain,
            routeIDs: routeIds.map(RouteID.init(rawValue:))
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
