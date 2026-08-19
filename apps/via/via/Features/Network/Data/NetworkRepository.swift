import Foundation
import OSLog

/// What the tiled station cache needs from the API — one method per payload.
/// A seam so `LiveNetworkRepository`'s caching behavior is testable with an
/// in-memory remote instead of a stubbed HTTP stack.
protocol NetworkRemote: Sendable {
    func railMap() async throws -> TransitNetwork
    func stationsTile(in bounds: GeoBounds) async throws -> StationsArea
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
}

actor LiveNetworkRepository: NetworkRepository {
    /// Above this many visible tiles the viewport is zoomed out past the
    /// station threshold, so warming neighbours would be wasted work.
    private static let prefetchableVisibleTileCount = 9
    private static let prefetchTileLimit = 16

    private let remote: any NetworkRemote
    /// How long a failed tile stays quiet before it may be fetched again.
    /// Without it, a failing tile is retried on every map gesture, forever.
    private let retryCooldown: Duration
    private let clock = ContinuousClock()

    private var cache: [ViewportTile: StationsArea] = [:]
    private var failedTiles: [ViewportTile: ContinuousClock.Instant] = [:]
    private var inFlight: [ViewportTile: Task<StationsArea?, Never>] = [:]
    private var railMapTask: Task<TransitNetwork, Error>?
    private var lastAssembly: (tiles: Set<ViewportTile>, area: StationsArea)?

    init(remote: any NetworkRemote, retryCooldown: Duration = .seconds(120)) {
        self.remote = remote
        self.retryCooldown = retryCooldown
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
        let visibleTiles = ViewportTile.covering(bounds)
        let fetchableTiles = visibleTiles.filter { cache[$0] == nil && !isCoolingDown($0) }
        if fetchableTiles.isEmpty, let lastAssembly, lastAssembly.tiles == visibleTiles {
            prefetchNeighbours(of: visibleTiles)
            return lastAssembly.area
        }

        for task in fetchableTiles.map({ tileTask($0) }) {
            _ = await task.value
        }
        try Task.checkCancellation()

        var stationsByID: [StationID: NetworkStation] = [:]
        var routesByID: [RouteID: RouteBadge] = [:]
        for tile in visibleTiles {
            guard let area = cache[tile] else { continue }
            area.stations.forEach { stationsByID[$0.id] = $0 }
            area.routes.forEach { routesByID[$0.id] = $0 }
        }

        let area = StationsArea(
            stations: stationsByID.values.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending },
            routes: routesByID.values.sorted { $0.shortName.localizedStandardCompare($1.shortName) == .orderedAscending }
        )
        lastAssembly = (tiles: visibleTiles, area: area)
        prefetchNeighbours(of: visibleTiles)
        return area
    }

    /// One shared fetch per tile: concurrent viewports (the map and the
    /// nearest-station flow overlap constantly) await the same task, and a
    /// caller's cancellation doesn't abort a fetch someone else may still cache.
    private func tileTask(
        _ tile: ViewportTile,
        priority: TaskPriority? = nil
    ) -> Task<StationsArea?, Never> {
        if let existing = inFlight[tile] { return existing }
        let task = Task(priority: priority) { () async -> StationsArea? in
            defer { inFlight[tile] = nil }
            do {
                guard tile.bounds.isValid else {
                    throw ViaError.invalidRequest("viewport")
                }
                let area = try await remote.stationsTile(in: tile.bounds)
                cache[tile] = area
                failedTiles[tile] = nil
                return area
            } catch is CancellationError {
                return nil
            } catch {
                failedTiles[tile] = clock.now
                AppLog.network.error("Viewport tile failed: \(String(describing: error), privacy: .private(mask: .hash))")
                return nil
            }
        }
        inFlight[tile] = task
        return task
    }

    private func isCoolingDown(_ tile: ViewportTile) -> Bool {
        guard let failedAt = failedTiles[tile] else { return false }
        if clock.now - failedAt < retryCooldown { return true }
        failedTiles[tile] = nil
        return false
    }

    /// Warms the ring of tiles around the viewport at background priority, so
    /// the next pan lands on cached data instead of a request.
    private func prefetchNeighbours(of visibleTiles: Set<ViewportTile>) {
        guard !visibleTiles.isEmpty,
              visibleTiles.count <= Self.prefetchableVisibleTileCount else { return }

        var ring: Set<ViewportTile> = []
        for tile in visibleTiles {
            for latitudeOffset in -1...1 {
                for longitudeOffset in -1...1 {
                    ring.insert(ViewportTile(
                        latitudeIndex: tile.latitudeIndex + latitudeOffset,
                        longitudeIndex: tile.longitudeIndex + longitudeOffset
                    ))
                }
            }
        }

        let candidates = ring.subtracting(visibleTiles).filter {
            cache[$0] == nil && inFlight[$0] == nil && !isCoolingDown($0)
        }
        for tile in candidates.prefix(Self.prefetchTileLimit) {
            _ = tileTask(tile, priority: .utility)
        }
    }
}
