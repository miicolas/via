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
    let sharedMobility: SharedMobilityItem?
    let sharedMobilityCluster: SharedMobilityCluster?
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
        bikeStation: BikeStation? = nil,
        sharedMobility: SharedMobilityItem? = nil,
        sharedMobilityCluster: SharedMobilityCluster? = nil
    ) {
        self.id = id
        self.name = name
        self.coordinate = coordinate
        self.routes = routes
        self.accessibility = accessibility
        self.hasElevators = hasElevators
        self.toilets = toilets
        self.bikeStation = bikeStation
        self.sharedMobility = sharedMobility
        self.sharedMobilityCluster = sharedMobilityCluster
        self.modes = routes.modes
    }

    /// Docks and transit stops share one annotation id space, so a dock's GBFS
    /// id is namespaced before it becomes a `StationID`. Local to the map: the
    /// wire format tells the two apart by kind, not by prefix.
    static let bikeStationIDPrefix = "velib:"
    static let sharedMobilityIDPrefix = "mobility:"

    init(bikeStation: BikeStation) {
        self.init(
            id: StationID(rawValue: "\(Self.bikeStationIDPrefix)\(bikeStation.id)"),
            name: bikeStation.name,
            coordinate: bikeStation.coordinate,
            routes: [],
            bikeStation: bikeStation
        )
    }

    init(sharedMobility: SharedMobilityItem) {
        self.init(
            id: StationID(rawValue: "\(Self.sharedMobilityIDPrefix)\(sharedMobility.id)"),
            name: sharedMobility.name,
            coordinate: sharedMobility.coordinate,
            routes: [],
            sharedMobility: sharedMobility
        )
    }

    init(sharedMobilityCluster: SharedMobilityCluster) {
        self.init(
            id: StationID(rawValue: "mobility-cluster:\(sharedMobilityCluster.id)"),
            name: "\(sharedMobilityCluster.count) \(sharedMobilityCluster.mode.displayName)",
            coordinate: sharedMobilityCluster.coordinate,
            routes: [],
            sharedMobilityCluster: sharedMobilityCluster
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

}

extension StationMapItem {
    /// The dock behind this pin, whichever route delivered it — the Vélib'
    /// layer or the generic one.
    ///
    /// Asking the two questions separately is what let a screen answer for one
    /// source and not the other: the same station arrived as a `BikeStation`
    /// here and as a `SharedMobilityItem` there, and every reader had to
    /// remember both.
    var dock: BikeStation? {
        if let bikeStation { return bikeStation }
        if case .station(let generic)? = sharedMobility { return generic.station }
        return nil
    }

    /// Whether this pin is shared mobility its source still vouches for.
    ///
    /// Written once: the map and the nearby list must expire a scooter on the
    /// same tick, and a TTL rule kept in two places lets it vanish from one
    /// screen while the other still offers to unlock it.
    func isCurrentSharedMobility(
        in sources: [SharedMobilityProvider: SharedMobilitySourceStatus],
        at date: Date = .now
    ) -> Bool {
        guard let mobility = sharedMobility else { return false }
        return sources[mobility.provider]?.isCurrent(at: date) ?? false
    }
}

extension BikeStationsArea {
    var mapItems: [StationMapItem] {
        stations.map(StationMapItem.init(bikeStation:))
    }
}

extension SharedMobilityArea {
    var mapItems: [StationMapItem] {
        items.map(StationMapItem.init(sharedMobility:))
    }
}

extension Array where Element == StationMapItem {
    /// Keeps sparse close-zoom vehicles individual, collapses dense piles that
    /// would make SwiftUI build dozens of annotations at one point, and uses a
    /// broader grid when the map is dezoomed. Physical Vélib’ stations are
    /// intentionally never merged.
    func groupedSharedMobility(for viewport: NetworkViewport) -> [StationMapItem] {
        viewport.groupsSharedMobility
            ? groupedSharedMobility()
            : denselyGroupedSharedMobility()
    }

    /// The overview grid alone, with no camera in it, so it can be cached and
    /// reused across continuous camera frames.
    func groupedSharedMobility() -> [StationMapItem] {
        groupedSharedMobility(
            cellSizeMeters: SharedMobilityGrouping.overviewCellSizeMeters,
            minimumClusterCount: 2
        )
    }

    /// A close-zoom safety net. Four vehicles inside one 20 m cell already
    /// overlap more than they can be tapped, while one to three remain useful
    /// individual choices.
    func denselyGroupedSharedMobility() -> [StationMapItem] {
        groupedSharedMobility(
            cellSizeMeters: SharedMobilityGrouping.denseCellSizeMeters,
            minimumClusterCount: SharedMobilityGrouping.denseMinimumClusterCount
        )
    }

    private func groupedSharedMobility(
        cellSizeMeters: Double,
        minimumClusterCount: Int
    ) -> [StationMapItem] {
        // The default map carries no vehicles at all, and every snapshot
        // publish came through here — a viewport change, a filter tap, both
        // sides of every refresh. Without this the whole station list was
        // partitioned and string-sorted to return itself.
        guard contains(where: { item in
            if case .vehicle = item.sharedMobility { return true }
            return false
        }) else { return self }

        let latitudeCellSize = cellSizeMeters / 111_000
        var grouped: [SharedMobilityClusterKey: [StationMapItem]] = [:]
        var untouched: [StationMapItem] = []

        for item in self {
            guard let mobility = item.sharedMobility,
                  case .vehicle(let vehicle) = mobility
            else {
                untouched.append(item)
                continue
            }

            let longitudeCellSize = cellSizeMeters
                / Swift.max(0.01, 111_000 * cos(vehicle.coordinate.latitude * .pi / 180))
            let key = SharedMobilityClusterKey(
                provider: vehicle.provider,
                mode: vehicle.mode,
                latitudeIndex: Int(floor(vehicle.coordinate.latitude / latitudeCellSize)),
                longitudeIndex: Int(floor(vehicle.coordinate.longitude / longitudeCellSize))
            )
            grouped[key, default: []].append(item)
        }

        let clusters = grouped.flatMap { key, items -> [StationMapItem] in
            guard items.count >= minimumClusterCount else { return items }
            let latitude = items.map(\.coordinate.latitude).reduce(0, +) / Double(items.count)
            let longitude = items.map(\.coordinate.longitude).reduce(0, +) / Double(items.count)
            let clusterID = [
                "\(Int(cellSizeMeters))m",
                key.provider.rawValue,
                key.mode.rawValue,
                String(key.latitudeIndex),
                String(key.longitudeIndex),
            ].joined(separator: ":")
            return [StationMapItem(sharedMobilityCluster: SharedMobilityCluster(
                id: clusterID,
                coordinate: GeoCoordinate(latitude: latitude, longitude: longitude),
                provider: key.provider,
                mode: key.mode,
                count: items.count
            ))]
        }

        // The vehicle output comes from a dictionary, whose iteration order is
        // not stable between publishes, and an annotation that changes index
        // flickers. `untouched` already arrives in the source's own order.
        return untouched + clusters.sorted { $0.id.rawValue < $1.id.rawValue }
    }
}

private enum SharedMobilityGrouping {
    static let overviewCellSizeMeters = 250.0
    static let denseCellSizeMeters = 20.0
    static let denseMinimumClusterCount = 4
}

private struct SharedMobilityClusterKey: Hashable {
    let provider: SharedMobilityProvider
    let mode: SharedMobilityMode
    let latitudeIndex: Int
    let longitudeIndex: Int
}
