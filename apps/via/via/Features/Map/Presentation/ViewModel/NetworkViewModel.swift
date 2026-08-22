import Foundation
import OSLog
import Observation

@MainActor
@Observable
final class NetworkViewModel {
  private(set) var state: NetworkMapState = .idle

  @ObservationIgnored private let repository: any NetworkRepository
  @ObservationIgnored private var routeLayout: TransitRouteLayout?
  @ObservationIgnored private var positionedRoutes: [NetworkRoute] = []
  @ObservationIgnored private var positionedViewport: TransitMapViewport?
  @ObservationIgnored private var routesGeneration = 0
  @ObservationIgnored private var loadedStations: [StationMapItem] = []
  @ObservationIgnored private var viewportTask: Task<Void, Never>?
  @ObservationIgnored private var viewportRevision = 0
  @ObservationIgnored private var lastViewport: NetworkViewport?

  init(repository: any NetworkRepository) {
    self.repository = repository
  }

  /// Fetches and prepares the static network before the map gets its first
  /// viewport. The viewport-specific positioning still happens when the map
  /// appears, because it depends on the rendered map size and zoom.
  func preload() async {
    guard routeLayout == nil else { return }

    do {
      let network = try await repository.railMap()
      try Task.checkCancellation()

      let layout = await Task.detached(priority: .userInitiated) {
        TransitRouteLayout(routes: network.routes)
      }.value
      try Task.checkCancellation()

      if routeLayout == nil {
        routeLayout = layout
      }
    } catch is CancellationError {
    } catch {
      AppLog.network.error(
        "Network preload failed: \(String(describing: error), privacy: .private(mask: .hash))"
      )
    }
  }

  func viewportChanged(to viewport: NetworkViewport, phase: NetworkViewportPhase) {
    lastViewport = viewport
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

  func retry() {
    guard let lastViewport else { return }
    viewportChanged(to: lastViewport, phase: .ended)
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

      // Lane positions depend only on the viewport's shape, not its
      // center: skip the recompute (and the generation bump) when a pan
      // lands on the same zoom, so the published routes stay identical.
      let mapViewport = viewport.transitMapViewport
      if routeLayout == nil || positionedViewport != mapViewport {
        let routes = await Task.detached(priority: .userInitiated) {
          layout.positioned(in: mapViewport)
        }.value
        try Task.checkCancellation()
        guard revision == viewportRevision else { return }
        positionedRoutes = routes
        positionedViewport = mapViewport
        routesGeneration &+= 1
      }
      guard revision == viewportRevision else { return }

      routeLayout = layout
      publishSnapshot(for: viewport, loading: .loading)

      if viewport.showsStations {
        let fetchedStations = try await repository.viewport(in: viewport.bounds).mapItems
        try Task.checkCancellation()
        guard revision == viewportRevision else { return }
        loadedStations = fetchedStations
      }
      publishSnapshot(for: viewport, loading: .loaded)
      AppLog.network.debug(
        "Map snapshot loaded with \(self.positionedRoutes.count, privacy: .public) routes"
      )
    } catch is CancellationError {
    } catch {
      guard revision == viewportRevision else { return }
      state.loading = .failed(error.via)
      AppLog.network.error(
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
        routesGeneration: routesGeneration,
        stations: visibleStations,
        lineStyle: viewport.lineStyle,
        stationOpacity: viewport.stationOpacity
      ),
      loading: loading
    )
    if state != refreshed { state = refreshed }
  }
}
