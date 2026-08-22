import Foundation

struct StationMapItem: Identifiable, Sendable, Hashable {
    let id: StationID
    let name: String
    let coordinate: GeoCoordinate
    let routes: [RouteBadge]
    let accessibility: StationAccessibility?
    /// Stored rather than derived: annotation bodies read it on every render.
    let modes: [TransitMode]

    init(
        id: StationID,
        name: String,
        coordinate: GeoCoordinate,
        routes: [RouteBadge],
        accessibility: StationAccessibility? = nil
    ) {
        self.id = id
        self.name = name
        self.coordinate = coordinate
        self.routes = routes
        self.accessibility = accessibility
        self.modes = routes.modes
    }
}

extension StationsArea {
    var mapItems: [StationMapItem] {
        let routeCatalog = StationRouteCatalog(routes: routes)

        return stations.map { station in
            return StationMapItem(
                id: station.id,
                name: station.name,
                coordinate: station.coordinate,
                routes: routeCatalog.routes(for: station.routeIDs),
                accessibility: station.accessibility
            )
        }
    }
}
