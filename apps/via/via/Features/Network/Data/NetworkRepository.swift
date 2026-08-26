import Foundation
import OSLog

/// What the tiled caches need from the API — one method per payload. A seam so
/// `LiveNetworkRepository`'s caching behavior is testable with an in-memory
/// remote instead of a stubbed HTTP stack.
protocol NetworkRemote: Sendable {
    func railMap() async throws -> TransitNetwork
    func stationsTile(in bounds: GeoBounds) async throws -> StationsArea
    func bikeStationsTile(in bounds: GeoBounds) async throws -> BikeStationsArea
    func sharedMobilityTile(in bounds: GeoBounds) async throws -> SharedMobilityArea
}

extension NetworkRemote {
    func sharedMobilityTile(in bounds: GeoBounds) async throws -> SharedMobilityArea {
        SharedMobilityArea()
    }
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

    func sharedMobilityTile(in bounds: GeoBounds) async throws -> SharedMobilityArea {
        try await transport.perform("shared_mobility_in_area") { client in
            let input = Operations.network_period_sharedMobilityInArea.Input(query: .init(
                minLatitude: bounds.minLatitude,
                maxLatitude: bounds.maxLatitude,
                minLongitude: bounds.minLongitude,
                maxLongitude: bounds.maxLongitude
            ))
            switch try await client.network_period_sharedMobilityInArea(input) {
            case .ok(let response):
                return try transport.convert(
                    response.body.json,
                    to: SharedMobilityAreaDTO.self
                ).domain()
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
    private let mobility: ViewportTileCache<SharedMobilityArea>
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
        // The API enforces each provider's GBFS TTL. Shared mobility is not
        // retained in the client tile cache: ttl=0 feeds must never be reused,
        // and the response itself is cheap because the API shares provider
        // snapshots process-wide.
        mobility = ViewportTileCache(
            freshness: .seconds(0),
            retryCooldown: retryCooldown,
            empty: .unavailable,
            fetch: { bounds in
                do {
                    return try await remote.sharedMobilityTile(in: bounds)
                } catch is CancellationError {
                    throw CancellationError()
                } catch {
                    // Unlike reference-data tiles, a failed mobility request
                    // must replace the old coordinates with an unavailable
                    // snapshot so a transport outage cannot keep stale pins
                    // on screen past their source TTL.
                    return .unavailable
                }
            },
            merge: Self.mergeSharedMobility
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

    func sharedMobility(in bounds: GeoBounds) async throws -> SharedMobilityArea {
        try await mobility.value(in: bounds)
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

    private static func mergeSharedMobility(_ areas: [SharedMobilityArea]) -> SharedMobilityArea {
        guard !areas.isEmpty else { return .unavailable }
        // Tile order, not dictionary order: the merged array indexes map
        // annotations, so it has to be stable from one merge to the next or
        // SwiftUI re-diffs the whole layer on every viewport change. Walking the
        // tiles in order and skipping ids already seen gives that stability in
        // one pass, where a dictionary needed an O(n log n) sort to recover it.
        var items: [SharedMobilityItem] = []
        var seenIDs: Set<String> = []
        var sources: [SharedMobilityProvider: SharedMobilitySourceStatus] = [:]

        for area in areas {
            for item in area.items {
                guard seenIDs.insert(item.id).inserted else { continue }
                items.append(item)
            }
            for provider in SharedMobilityProvider.allCases {
                let status = area.source(provider)
                if let previous = sources[provider] {
                    sources[provider] = previous.isAvailable && status.isAvailable
                        ? status
                        : SharedMobilitySourceStatus(state: .unavailable)
                } else {
                    sources[provider] = status
                }
            }
        }

        return SharedMobilityArea(items: items, sources: sources)
    }
}
