import Foundation

struct StationMapItem: Identifiable, Sendable, Hashable {
    let id: StationID
    let name: String
    let coordinate: GeoCoordinate
    let routes: [RouteBadge]
    let accessibility: StationAccessibility?
    let hasElevators: Bool
    let toilets: StationToilets?
    let bikeStation: BikeStation?
    /// Stored rather than derived: annotation bodies read it on every render.
    let modes: [TransitMode]

    init(
        id: StationID,
        name: String,
        coordinate: GeoCoordinate,
        routes: [RouteBadge],
        accessibility: StationAccessibility? = nil,
        hasElevators: Bool = false,
        toilets: StationToilets? = nil,
        bikeStation: BikeStation? = nil
    ) {
        self.id = id
        self.name = name
        self.coordinate = coordinate
        self.routes = routes
        self.accessibility = accessibility
        self.hasElevators = hasElevators
        self.toilets = toilets
        self.bikeStation = bikeStation
        self.modes = routes.modes
    }

    init(bikeStation: BikeStation) {
        self.init(
            id: StationID(rawValue: "\(BikeStation.resultIDPrefix)\(bikeStation.id)"),
            name: bikeStation.name,
            coordinate: bikeStation.coordinate,
            routes: [],
            bikeStation: bikeStation
        )
    }
}

extension StationsArea {
    /// Kept as two lists rather than one: the bike layer is opt-in, and the
    /// map re-filters what it holds on every camera frame.
    var transitMapItems: [StationMapItem] {
        let routeCatalog = StationRouteCatalog(routes: routes)

        return stations.map { station in
            StationMapItem(
                id: station.id,
                name: station.name,
                coordinate: station.coordinate,
                routes: routeCatalog.routes(for: station.routeIDs),
                accessibility: station.accessibility,
                hasElevators: station.hasElevators,
                toilets: station.toilets
            )
        }
    }

    var bikeMapItems: [StationMapItem] {
        bikeStations.map(StationMapItem.init(bikeStation:))
    }
}
