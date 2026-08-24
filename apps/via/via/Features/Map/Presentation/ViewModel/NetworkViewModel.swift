import Foundation
import OSLog
import Observation

@MainActor
@Observable
final class NetworkViewModel {
  private(set) var state: NetworkMapState = .idle

  /// Reads and writes the one filter the Stations list shares, so a criterion
  /// set on the map cannot show a different set of stations in the list.
  var stationFilter: StationMapFilter {
    get { filterStore.filter }
    set { filterStore.filter = newValue }
  }

  @ObservationIgnored let filterStore: StationMapFilterStore
  /// Absent in isolation, where the map is the only consumer: the off-threshold
  /// annotations are the nearby set, and there is no nearby set without it.
  @ObservationIgnored private let nearby: NearbyStationsModel?
  @ObservationIgnored private let repository: any NetworkRepository
  @ObservationIgnored private var routeLayout: TransitRouteLayout?
  @ObservationIgnored private var positionedRoutes: [NetworkRoute] = []
  @ObservationIgnored private var positionedViewport: TransitMapViewport?
  @ObservationIgnored private var routesGeneration = 0
  @ObservationIgnored private var loadedStations: [StationMapItem] = []
  /// Kept apart from `loadedStations`: the layer is off by default, and
  /// `publishSnapshot` runs on every camera frame — no reason to walk a
  /// thousand docks per frame only to reject them.
  @ObservationIgnored private var loadedBikeStations: [StationMapItem] = []
  @ObservationIgnored private var bikeSourceAvailable = true
  @ObservationIgnored private var bikeRefreshTask: Task<Void, Never>?
  @ObservationIgnored private var viewportTask: Task<Void, Never>?
  @ObservationIgnored private var viewportRevision = 0
  @ObservationIgnored private var lastViewport: NetworkViewport?

  init(
    repository: any NetworkRepository,
    filterStore: StationMapFilterStore = StationMapFilterStore(),
    nearby: NearbyStationsModel? = nil
  ) {
    self.repository = repository
    self.filterStore = filterStore
    self.nearby = nearby
    filterStore.onChange { [weak self] _ in
      self?.filterChanged()
    }
    nearby?.onResultsChange { [weak self] in
      self?.nearbyResultsChanged()
    }
  }

  private func filterChanged() {
    scheduleBikeRefresh()
    guard let lastViewport else { return }
    publishSnapshot(for: lastViewport, loading: state.loading)
  }

  /// Only matters where the nearby set *is* what is drawn; below the threshold
  /// the annotations come from the viewport's own stations.
  private func nearbyResultsChanged() {
    guard let lastViewport, !lastViewport.showsStations, stationFilter.isActive else { return }
    publishSnapshot(for: lastViewport, loading: state.loading)
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
    // The centre of the frame anchors the nearby set: it needs no location
    // permission, and it follows what the traveller is looking at. Only on a
    // settled camera — a re-sort mid-gesture would move rows under a thumb.
    if phase == .ended {
      nearby?.anchorChanged(to: viewport.center)
    }
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
        // The two payloads are independent routes with independent caches, so
        // they travel together; the docks are skipped entirely with the layer
        // off, which is the default.
        async let stationsArea = repository.viewport(in: viewport.bounds)
        async let bikeArea: BikeStationsArea? =
          stationFilter.contains(.bikeStations)
          ? try await repository.bikeStations(in: viewport.bounds)
          : nil

        let (fetchedStations, fetchedBikes) = try await (stationsArea, bikeArea)
        try Task.checkCancellation()
        guard revision == viewportRevision else { return }
        loadedStations = fetchedStations.transitMapItems
        loadedBikeStations = fetchedBikes?.mapItems ?? []
        bikeSourceAvailable = fetchedBikes?.sourceAvailable ?? true
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

  func stationMapItem(for stationID: StationID) -> StationMapItem? {
    loadedStations.first { $0.id == stationID }
      ?? loadedBikeStations.first { $0.id == stationID }
      ?? nearby?.results.first { $0.id == stationID }?.item
  }

  /// Dock counts move by the minute while the rest of a tile is reference
  /// data, so the layer being on is what decides the refresh — not the view
  /// that happens to be drawing it. Only the docks are refetched: the stations
  /// and their badges have not changed since the tile was first loaded.
  private func scheduleBikeRefresh() {
    bikeRefreshTask?.cancel()
    guard stationFilter.contains(.bikeStations) else {
      loadedBikeStations = []
      bikeSourceAvailable = true
      return
    }
    bikeRefreshTask = Task { [weak self] in
      // Turning the layer on is itself a request for counts; the loop below
      // only keeps them from going stale afterwards.
      await self?.refreshBikeStations()
      while !Task.isCancelled {
        do {
          try await Task.sleep(for: BikeStation.freshness)
        } catch {
          return
        }
        guard let self else { return }
        await refreshBikeStations()
      }
    }
  }

  private func refreshBikeStations() async {
    guard let viewport = lastViewport,
          viewport.showsStations,
          stationFilter.contains(.bikeStations) else { return }
    let revision = viewportRevision
    do {
      let area = try await repository.bikeStations(in: viewport.bounds)
      guard revision == viewportRevision, stationFilter.contains(.bikeStations) else { return }
      loadedBikeStations = area.mapItems
      bikeSourceAvailable = area.sourceAvailable
      publishSnapshot(for: viewport, loading: state.loading)
    } catch is CancellationError {
    } catch {
      AppLog.network.error(
        "Bike refresh failed: \(String(describing: error), privacy: .private(mask: .hash))"
      )
    }
  }

  private func publishSnapshot(
    for viewport: NetworkViewport,
    loading: NetworkMapLoadingState
  ) {
    var visibleStations: [StationMapItem] = []
    var bypassZoomFade = false
    var sourceAvailable = bikeSourceAvailable
    if viewport.showsStations {
      let bounds = viewport.bounds
      visibleStations = loadedStations.filter {
        bounds.contains($0.coordinate) && stationFilter.matches($0)
      }
      if stationFilter.contains(.bikeStations) {
        visibleStations += loadedBikeStations.filter {
          bounds.contains($0.coordinate) && stationFilter.matches($0)
        }
      }
    } else if stationFilter.isActive,
              let nearby,
              viewport.fitsInside(radiusMeters: NearbyStationsModel.radiusMeters) {
      // A bounded nearby query is only safe to draw while its radius covers
      // the entire viewport. Past that point every symbol disappears instead
      // of revealing the circular edge of the loaded data.
      visibleStations = nearby.annotationItems
      bypassZoomFade = !visibleStations.isEmpty
      sourceAvailable = nearby.bikeSourceAvailable
    }
    // A mode criterion narrows the drawn network too: filtering on the métro
    // keeps every RER and tram polyline off the map, not just their stations.
    let routeModes = stationFilter.transitModes
    let visibleRoutes = routeModes.isEmpty
      ? positionedRoutes
      : positionedRoutes.filter { routeModes.contains($0.badge.mode) }
    let refreshed = NetworkMapState(
      snapshot: NetworkMapSnapshot(
        routes: visibleRoutes,
        routesGeneration: routesGeneration,
        routeModes: routeModes,
        stations: visibleStations,
        lineStyle: viewport.lineStyle,
        stationOpacity: viewport.stationOpacity,
        stationsBypassZoomFade: bypassZoomFade,
        bikeSourceAvailable: sourceAvailable
      ),
      loading: loading
    )
    if state != refreshed { state = refreshed }
  }
}
