import Foundation

struct StationMapItem: Identifiable, Sendable, Hashable {
    let id: StationID
    let name: String
    let coordinate: GeoCoordinate
    let routes: [RouteBadge]
    /// Stored rather than derived: annotation bodies read it on every render.
    let modes: [TransitMode]

    init(id: StationID, name: String, coordinate: GeoCoordinate, routes: [RouteBadge]) {
        self.id = id
        self.name = name
        self.coordinate = coordinate
        self.routes = routes
        self.modes = TransitMode.allCases.filter { mode in
            routes.contains { $0.mode == mode }
        }
    }
}

extension StationsArea {
    var mapItems: [StationMapItem] {
        let routesByID = routes.reduce(into: [RouteID: RouteBadge]()) { result, route in
            result[route.id] = route
        }

        return stations.map { station in
            var seenRouteIDs: Set<RouteID> = []
            let stationRoutes = station.routeIDs
                .filter { seenRouteIDs.insert($0).inserted }
                .compactMap { routesByID[$0] }
                .sorted { lhs, rhs in
                    if lhs.mode != rhs.mode {
                        return lhs.mode < rhs.mode
                    }
                    return lhs.shortName.localizedStandardCompare(rhs.shortName) == .orderedAscending
                }

            return StationMapItem(
                id: station.id,
                name: station.name,
                coordinate: station.coordinate,
                routes: stationRoutes
            )
        }
    }
}
