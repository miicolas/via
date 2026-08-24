import Foundation
import OSLog

/// What the tiled caches need from the API — one method per payload. A seam so
/// `LiveNetworkRepository`'s caching behavior is testable with an in-memory
/// remote instead of a stubbed HTTP stack.
protocol NetworkRemote: Sendable {
    func railMap() async throws -> TransitNetwork
    func stationsTile(in bounds: GeoBounds) async throws -> StationsArea
    func bikeStationsTile(in bounds: GeoBounds) async throws -> BikeStationsArea
}

struct APINetworkRemote: NetworkRemote {
    let transport: APITransport

    func railMap() async throws -> TransitNetwork {
        try await transport.perform("rail_map") { client in
            switch try await client.network_period_railMap(.init()) {
            case .ok(let response):
                return try transport.convert(response.body.json, to: RailMapDTO.self).domain()
            case .undocumented(let statusCode, _):
                throw APITransport.error(for: statusCode)
            }
        }
    }

    func stationsTile(in bounds: GeoBounds) async throws -> StationsArea {
        try await transport.perform("stations_in_area") { client in
            let input = Operations.network_period_stationsInArea.Input(query: .init(
                minLatitude: bounds.minLatitude,
                maxLatitude: bounds.maxLatitude,
                minLongitude: bounds.minLongitude,
                maxLongitude: bounds.maxLongitude
            ))
            switch try await client.network_period_stationsInArea(input) {
            case .ok(let response):
                return try transport.convert(
                    response.body.json,
                    to: StationsAreaDTO.self
                ).domain()
            case .undocumented(let statusCode, _):
                throw APITransport.error(for: statusCode)
            }
        }
    }

    func bikeStationsTile(in bounds: GeoBounds) async throws -> BikeStationsArea {
        try await transport.perform("bike_stations_in_area") { client in
            let input = Operations.network_period_bikeStationsInArea.Input(query: .init(
                minLatitude: bounds.minLatitude,
                maxLatitude: bounds.maxLatitude,
                minLongitude: bounds.minLongitude,
                maxLongitude: bounds.maxLongitude
            ))
            switch try await client.network_period_bikeStationsInArea(input) {
            case .ok(let response):
                return try transport.convert(
                    response.body.json,
                    to: BikeStationsAreaDTO.self
                ).domain
            case .undocumented(let statusCode, _):
                throw APITransport.error(for: statusCode)
            }
        }
    }
}

actor LiveNetworkRepository: NetworkRepository {
    private let remote: any NetworkRemote
    private let stations: ViewportTileCache<StationsArea>
    private let bikes: ViewportTileCache<BikeStationsArea>
    private var railMapTask: Task<TransitNetwork, Error>?

    init(remote: any NetworkRemote, retryCooldown: Duration = .seconds(120)) {
        self.remote = remote
        // Reference data: a fetched tile stands until the app is relaunched.
        stations = ViewportTileCache(
            freshness: nil,
            retryCooldown: retryCooldown,
            empty: StationsArea(stations: [], routes: []),
            fetch: { try await remote.stationsTile(in: $0) },
            merge: Self.mergeStations
        )
        // Dock counts: a tile is worth a minute, and no longer.
        bikes = ViewportTileCache(
            freshness: BikeStation.freshness,
            retryCooldown: retryCooldown,
            empty: BikeStationsArea(),
            fetch: { try await remote.bikeStationsTile(in: $0) },
            merge: Self.mergeBikeStations
        )
    }

    init(transport: APITransport) {
        self.init(remote: APINetworkRemote(transport: transport))
    }

    func railMap() async throws -> TransitNetwork {
        if let railMapTask { return try await railMapTask.value }
        let remote = remote
        let task = Task { try await remote.railMap() }
        railMapTask = task
        do {
            return try await task.value
        } catch {
            railMapTask = nil
            throw error
        }
    }

    func viewport(in bounds: GeoBounds) async throws -> StationsArea {
        try await stations.value(in: bounds)
    }

    func bikeStations(in bounds: GeoBounds) async throws -> BikeStationsArea {
        try await bikes.value(in: bounds)
    }

    /// Tiles overlap, so the same station can arrive twice; the badge list is
    /// deduplicated across the whole area rather than per tile.
    private static func mergeStations(_ areas: [StationsArea]) -> StationsArea {
        var stationsByID: [StationID: NetworkStation] = [:]
        var routesByID: [RouteID: RouteBadge] = [:]
        for area in areas {
            area.stations.forEach { stationsByID[$0.id] = $0 }
            area.routes.forEach { routesByID[$0.id] = $0 }
        }
        return StationsArea(
            stations: stationsByID.values.sorted {
                $0.name.localizedStandardCompare($1.name) == .orderedAscending
            },
            routes: routesByID.values.sorted {
                $0.shortName.localizedStandardCompare($1.shortName) == .orderedAscending
            }
        )
    }

    /// One failed tile means the feed is doubtful for the whole area: the map
    /// says so rather than drawing a partial network as if it were complete.
    private static func mergeBikeStations(_ areas: [BikeStationsArea]) -> BikeStationsArea {
        var stationsByID: [String: BikeStation] = [:]
        var sourceAvailable = true
        for area in areas {
            area.stations.forEach { stationsByID[$0.id] = $0 }
            sourceAvailable = sourceAvailable && area.sourceAvailable
        }
        return BikeStationsArea(
            stations: stationsByID.values.sorted {
                $0.name.localizedStandardCompare($1.name) == .orderedAscending
            },
            sourceAvailable: sourceAvailable
        )
    }
}
