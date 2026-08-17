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
                : (routeLayout != nil ? .loaded : .idle)
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

            var fetchedStations: [StationMapItem]?
            if viewport.showsStations {
                fetchedStations = try await repository.viewport(in: viewport.bounds).mapItems
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
            if let fetchedStations {
                loadedStations = fetchedStations
            }
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
        let visibleStations: [StationMapItem]
        if viewport.showsStations {
            let bounds = viewport.bounds
            visibleStations = loadedStations.filter { bounds.contains($0.coordinate) }
        } else {
            visibleStations = []
        }
        let refreshed = NetworkMapState(
            snapshot: NetworkMapSnapshot(
                routes: positionedRoutes,
                stations: visibleStations,
                lineStyle: viewport.lineStyle,
                stationOpacity: viewport.stationOpacity
            ),
            loading: loading
        )
        if state != refreshed { state = refreshed }
    }
}
