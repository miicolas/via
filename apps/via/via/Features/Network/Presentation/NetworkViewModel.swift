import Foundation
import Observation
import OSLog

@MainActor
@Observable
final class NetworkViewModel {
    private(set) var state: NetworkMapState = .idle

    @ObservationIgnored private let repository: any NetworkRepository
    @ObservationIgnored private var routeLayout: TransitRouteLayout?
    @ObservationIgnored private var positionedRoutes: [NetworkRoute] = []
    @ObservationIgnored private var loadedStations: [StationMapItem] = []
    @ObservationIgnored private var viewportTask: Task<Void, Never>?
    @ObservationIgnored private var viewportRevision = 0
    @ObservationIgnored private var hasLoadedSnapshot = false

    init(repository: any NetworkRepository) {
        self.repository = repository
    }

    func viewportChanged(to viewport: NetworkViewport, phase: NetworkViewportPhase) {
        viewportRevision &+= 1
        let revision = viewportRevision
        viewportTask?.cancel()
        publishSnapshot(
            for: viewport,
            loading: phase == .ended
                ? .loading
                : (hasLoadedSnapshot ? .loaded : .idle)
        )

        guard phase == .ended else { return }
        viewportTask = Task { [weak self] in
            guard let self else { return }
            await self.loadSnapshot(for: viewport, revision: revision)
        }
    }

    private func loadSnapshot(for viewport: NetworkViewport, revision: Int) async {
        do {
            let layout: TransitRouteLayout
            if let routeLayout {
                layout = routeLayout
            } else {
                let network = try await repository.railMap()
                layout = await Task.detached(priority: .userInitiated) {
                    TransitRouteLayout(routes: network.routes)
                }.value
            }
            try Task.checkCancellation()

            let stations: [StationMapItem]
            if viewport.showsStations {
                let area = try await repository.viewport(in: viewport.bounds)
                stations = area.mapItems
            } else {
                stations = loadedStations
            }
            try Task.checkCancellation()

            let mapViewport = viewport.transitMapViewport
            let routes = await Task.detached(priority: .userInitiated) {
                layout.positioned(in: mapViewport)
            }.value
            try Task.checkCancellation()
            guard revision == viewportRevision else { return }

            routeLayout = layout
            positionedRoutes = routes
            if viewport.showsStations {
                loadedStations = stations
            }
            hasLoadedSnapshot = true
            publishSnapshot(for: viewport, loading: .loaded)
            ViaLog.network.debug(
                "Map snapshot loaded with \(routes.count, privacy: .public) routes"
            )
        } catch is CancellationError {
        } catch {
            guard revision == viewportRevision else { return }
            state.loading = .failed(error.via)
            ViaLog.network.error(
                "Map snapshot failed: \(String(describing: error), privacy: .private(mask: .hash))"
            )
        }
    }

    private func publishSnapshot(
        for viewport: NetworkViewport,
        loading: NetworkMapLoadingState
    ) {
        state = NetworkMapState(
            snapshot: NetworkMapSnapshot(
                routes: positionedRoutes,
                stations: viewport.showsStations
                    ? loadedStations.filter { viewport.contains($0.coordinate) }
                    : [],
                lineStyle: viewport.lineStyle,
                stationOpacity: viewport.stationOpacity
            ),
            loading: loading
        )
    }
}
