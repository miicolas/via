import Foundation
import OSLog

protocol NetworkRepository: Sendable {
    func railMap() async throws -> TransitNetwork
    func viewport(in bounds: GeoBounds) async throws -> StationsArea
}

actor LiveNetworkRepository: NetworkRepository {
    private let client: any ViaAPIClient
    private var cache: [ViewportTile: StationsArea] = [:]
    private var railMapTask: Task<TransitNetwork, Error>?
    private var lastAssembly: (tiles: Set<ViewportTile>, area: StationsArea)?

    init(client: any ViaAPIClient) {
        self.client = client
    }

    func railMap() async throws -> TransitNetwork {
        if let railMapTask { return try await railMapTask.value }
        let task = Task { [client] in try await client.loadRailMap() }
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
        let client = client

        let loaded = try await withThrowingTaskGroup(
            of: (ViewportTile, StationsArea?).self,
            returning: [(ViewportTile, StationsArea)].self
        ) { group in
            for tile in missingTiles {
                group.addTask {
                    do {
                        return (tile, try await client.loadStations(in: tile.bounds))
                    } catch is CancellationError {
                        throw CancellationError()
                    } catch {
                        ViaLog.network.error("Viewport tile failed: \(String(describing: error), privacy: .private(mask: .hash))")
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

struct InMemoryNetworkRepository: NetworkRepository {
    var network: TransitNetwork = .init(routes: [], stations: [])
    var area: StationsArea = .init(stations: [], routes: [])

    func railMap() async throws -> TransitNetwork { network }
    func viewport(in bounds: GeoBounds) async throws -> StationsArea { area }
}
