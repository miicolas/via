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
  @ObservationIgnored private var loadedStations: [StationMapItem] = [] {
    didSet { rebuildDrawableItems() }
  }
  /// Kept apart from `loadedStations`: the layer is off by default, and
  /// `publishSnapshot` runs on every camera frame — no reason to walk a
  /// thousand docks per frame only to reject them.
  @ObservationIgnored private var loadedBikeStations: [StationMapItem] = [] {
    didSet { rebuildDrawableItems() }
  }
  @ObservationIgnored private var loadedSharedMobility: [StationMapItem] = [] {
    didSet { rebuildDrawableItems() }
  }
  @ObservationIgnored private var sharedMobilitySources: [SharedMobilityProvider: SharedMobilitySourceStatus] = [:] {
    didSet { rebuildDrawableItems() }
  }

  /// What the map can draw, before it knows where the camera is.
  ///
  /// `publishSnapshot` runs on every frame of a pan, and none of the work below
  /// depends on the frame: the filter criteria, the source TTLs and the 250 m
  /// grid are functions of the loaded sets alone. Doing them here leaves the
  /// frame with a bounds test, and has the side benefit that a cluster's count
  /// no longer changes as its members cross the edge of the viewport.
  ///
  /// A `didSet` on each input rather than a call at each load and refresh path:
  /// there are five of those, and the one that forgets shows stale vehicles.
  @ObservationIgnored private var drawableStations: [StationMapItem] = []
  @ObservationIgnored private var drawableBikeStations: [StationMapItem] = []
  @ObservationIgnored private var drawableVehicles: [StationMapItem] = []
  @ObservationIgnored private var groupedVehicles: [StationMapItem] = []
  @ObservationIgnored private var sharedMobilityRefreshTask: Task<Void, Never>?
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
    scheduleSharedMobilityRefresh()
    rebuildDrawableItems()
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
        // they travel together. Shared mobility is skipped entirely with its
        // filters off, which keeps the default map on the transit path only.
        async let stationsArea = repository.viewport(in: viewport.bounds)
        async let sharedArea: SharedMobilityArea? =
          stationFilter.wantsSharedMobility
          ? try await repository.sharedMobility(in: viewport.bounds)
          : nil

        let (fetchedStations, fetchedShared) = try await (stationsArea, sharedArea)
        try Task.checkCancellation()
        guard revision == viewportRevision else { return }
        loadedStations = fetchedStations.transitMapItems
        loadedSharedMobility = fetchedShared?.currentItems().map { StationMapItem(sharedMobility: $0) } ?? []
        sharedMobilitySources = fetchedShared?.sources ?? [:]

        loadedBikeStations = try await repository.legacyBikeStations(
          in: viewport.bounds,
          whenGenericSourcesAre: sharedMobilitySources,
          wanted: stationFilter.contains(.bikeStations)
        ).mapItems
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
      ?? loadedSharedMobility.first { $0.id == stationID }
      ?? nearby?.results.first { $0.id == stationID }?.item
  }

  /// Shared mobility moves by the minute, so the layer being on is what
  /// decides the refresh — not the view that happens to be drawing it.
  private func scheduleSharedMobilityRefresh() {
    sharedMobilityRefreshTask?.cancel()
    guard stationFilter.wantsSharedMobility else {
      loadedBikeStations = []
      loadedSharedMobility = []
      sharedMobilitySources = [:]
      return
    }
    sharedMobilityRefreshTask = Task { [weak self] in
      // Turning the layer on is itself a request for counts; the loop below
      // only keeps them from going stale afterwards.
      await self?.refreshSharedMobility()
      while !Task.isCancelled {
        guard let delay = await self?.nextSharedMobilityRefreshDelay() else { return }
        do {
          try await Task.sleep(for: .milliseconds(Int64(delay * 1_000)))
        } catch {
          return
        }
        guard let self else { return }
        await refreshSharedMobility()
      }
    }
  }

  private func refreshSharedMobility() async {
    guard let viewport = lastViewport,
          stationFilter.wantsSharedMobility else { return }

    // At overview scale the nearby model owns the bounded result set. It must
    // refresh too; otherwise a valid nearby payload would outlive its GBFS TTL
    // while the map is still zoomed out.
    guard viewport.showsStations else {
      nearby?.refreshSharedMobility()
      return
    }

    let revision = viewportRevision
    publishSnapshot(for: viewport, loading: state.loading)
    do {
      let area = try await repository.sharedMobility(in: viewport.bounds)
      guard revision == viewportRevision, stationFilter.wantsSharedMobility else { return }
      loadedSharedMobility = area.currentItems().map { StationMapItem(sharedMobility: $0) }
      sharedMobilitySources = area.sources
      let legacy = try await repository.legacyBikeStations(
        in: viewport.bounds,
        whenGenericSourcesAre: area.sources,
        wanted: stationFilter.contains(.bikeStations)
      )
      guard revision == viewportRevision else { return }
      loadedBikeStations = legacy.mapItems
      publishSnapshot(for: viewport, loading: state.loading)
    } catch is CancellationError {
    } catch {
      guard revision == viewportRevision else { return }
      // A source that just crossed its TTL must disappear even if its next
      // refresh is unavailable. The old payload is never a fallback. Nothing
      // was assigned here, so the rebuild has to be asked for.
      rebuildDrawableItems()
      publishSnapshot(for: viewport, loading: state.loading)
      AppLog.network.error(
        "Shared mobility refresh failed: \(String(describing: error), privacy: .private(mask: .hash))"
      )
    }
  }

  /// A source whose expiry is already behind us has just been refreshed
  /// without moving forward — its GBFS feed is stalled, not late. Counting it
  /// would clamp the interval to its floor and poll every second for as long as
  /// the feed stays stuck, so only a future expiry sets the pace and a stalled
  /// layer retries on the same cadence the API uses for a failed provider.
  private static let stalledSharedMobilityRetry: TimeInterval = 15
  private static let sharedMobilityRefreshCeiling: TimeInterval = 60

  private func nextSharedMobilityRefreshDelay() -> TimeInterval? {
    guard stationFilter.wantsSharedMobility else { return nil }
    let secondsUntilExpiry = sharedMobilitySources.values
      .compactMap { $0.expiresAt?.timeIntervalSinceNow }
      .filter { $0 > 0 }
      .min()
    guard let secondsUntilExpiry else {
      let hasExpiry = sharedMobilitySources.values.contains { $0.expiresAt != nil }
      return hasExpiry ? Self.stalledSharedMobilityRetry : Self.sharedMobilityRefreshCeiling
    }
    return min(Self.sharedMobilityRefreshCeiling, max(1, secondsUntilExpiry))
  }

  /// Applies everything the camera has no say in: the active criteria, the
  /// per-source TTL, and the 250 m grouping the dezoomed map draws.
  private func rebuildDrawableItems() {
    let now = Date.now
    drawableStations = loadedStations.filter(stationFilter.matches)
    drawableBikeStations = stationFilter.contains(.bikeStations)
      ? loadedBikeStations.filter(stationFilter.matches)
      : []
    drawableVehicles = stationFilter.wantsSharedMobility
      ? loadedSharedMobility.filter {
          $0.isCurrentSharedMobility(in: sharedMobilitySources, at: now)
            && stationFilter.matches($0)
        }
      : []
    groupedVehicles = drawableVehicles.groupedSharedMobility()
  }

  private func publishSnapshot(
    for viewport: NetworkViewport,
    loading: NetworkMapLoadingState
  ) {
    var visibleStations: [StationMapItem] = []
    var bypassZoomFade = false
    var sources = sharedMobilitySources
    if viewport.showsStations {
      let bounds = viewport.bounds
      let vehicles = viewport.groupsSharedMobility ? groupedVehicles : drawableVehicles
      visibleStations = drawableStations.filter { bounds.contains($0.coordinate) }
        + drawableBikeStations.filter { bounds.contains($0.coordinate) }
        + vehicles.filter { bounds.contains($0.coordinate) }
    } else if stationFilter.isActive,
              let nearby,
              viewport.fitsInside(radiusMeters: NearbyStationsModel.radiusMeters) {
      // A bounded nearby query is only safe to draw while its radius covers
      // the entire viewport. Past that point every symbol disappears instead
      // of revealing the circular edge of the loaded data.
      visibleStations = nearby.annotationItems
      bypassZoomFade = !visibleStations.isEmpty
      sources = nearby.sharedMobilitySources
    }
    // The map's own vehicles are already grouped; only the nearby set drawn at
    // overview scale still arrives ungrouped.
    if !viewport.showsStations {
      visibleStations = visibleStations.groupedSharedMobility(for: viewport)
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
        sharedMobilitySources: sources
      ),
      loading: loading
    )
    if state != refreshed { state = refreshed }
  }

}
