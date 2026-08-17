import Foundation
import OSLog

actor LiveNetworkRepository: NetworkRepository {
    private let transport: APITransport
    private var cache: [ViewportTile: StationsArea] = [:]
    private var railMapTask: Task<TransitNetwork, Error>?
    private var lastAssembly: (tiles: Set<ViewportTile>, area: StationsArea)?

    init(transport: APITransport) {
        self.transport = transport
    }

    func railMap() async throws -> TransitNetwork {
        if let railMapTask { return try await railMapTask.value }
        let task = Task { [transport] in
            try await transport.perform("rail_map") { client in
                switch try await client.network_period_railMap(.init()) {
                case .ok(let response):
                    return try transport.convert(response.body.json, to: RailMapDTO.self).domain()
                case .undocumented(let statusCode, _):
                    throw APITransport.error(for: statusCode)
                }
            }
        }
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
        let missingTiles = visibleTiles.filter { cache[$0] == nil }
        if missingTiles.isEmpty, let lastAssembly, lastAssembly.tiles == visibleTiles {
            return lastAssembly.area
        }
        let transport = transport

        let loaded = try await withThrowingTaskGroup(
            of: (ViewportTile, StationsArea?).self,
            returning: [(ViewportTile, StationsArea)].self
        ) { group in
            for tile in missingTiles {
                group.addTask {
                    do {
                        guard tile.bounds.isValid else {
                            throw ViaError.invalidRequest("viewport")
                        }
                        let area = try await transport.perform("stations_in_area") { client in
                            let bounds = tile.bounds
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
                        return (tile, area)
                    } catch is CancellationError {
                        throw CancellationError()
                    } catch {
                        AppLog.network.error("Viewport tile failed: \(String(describing: error), privacy: .private(mask: .hash))")
                        return (tile, nil)
                    }
                }
            }

            var values: [(ViewportTile, StationsArea)] = []
            for try await (tile, area) in group {
                if let area { values.append((tile, area)) }
            }
            return values
        }

        try Task.checkCancellation()
        loaded.forEach { cache[$0.0] = $0.1 }

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
        return area
    }
}
