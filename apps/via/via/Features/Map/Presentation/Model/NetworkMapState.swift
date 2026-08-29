import Foundation

enum NetworkViewportPhase: Sendable, Equatable {
  case continuous
  case ended
}

struct NetworkViewport: Sendable, Hashable {
  let center: GeoCoordinate
  let latitudeDelta: Double
  let longitudeDelta: Double
  let width: Double
  let height: Double

  var maximumSpanMeters: Double {
    let latitudeMeters = latitudeDelta * 111_000
    let longitudeMeters = longitudeDelta * 111_000 * cos(center.latitude * .pi / 180)
    return max(latitudeMeters, longitudeMeters)
  }

  var bounds: GeoBounds {
    let latitudeRadius = latitudeDelta / 2
    let longitudeRadius = longitudeDelta / 2
    return GeoBounds(
      minLatitude: max(-90, center.latitude - latitudeRadius),
      maxLatitude: min(90, center.latitude + latitudeRadius),
      minLongitude: max(-180, center.longitude - longitudeRadius),
      maxLongitude: min(180, center.longitude + longitudeRadius)
    )
  }

  /// Whether a circular nearby query centred on this viewport covers every
  /// visible corner. A partial circle must never be drawn: its hard edge makes
  /// unloaded stations look like real gaps in the network.
  func fitsInside(radiusMeters: Double) -> Bool {
    guard radiusMeters > 0 else { return false }
    let latitudeRadiusMeters = latitudeDelta * 111_000 / 2
    let longitudeRadiusMeters = longitudeDelta * 111_000
      * cos(center.latitude * .pi / 180) / 2
    return hypot(latitudeRadiusMeters, longitudeRadiusMeters) <= radiusMeters
  }
}

struct NetworkLineStyle: Sendable, Equatable {
  let opacity: Double
  let width: Double
}

struct NetworkMapSnapshot: Sendable, Equatable {
  let routes: [NetworkRoute]
  /// Bumped whenever `routes` is replaced. Equality goes through it instead of
  /// the routes themselves: the deep compare walks every coordinate of every
  /// polyline, and the view model runs it on the main thread for each
  /// continuous camera frame.
  let routesGeneration: Int
  /// The modes `routes` was narrowed to before publishing; empty when the
  /// whole network is drawn. Part of equality because a filter change reslices
  /// the same generation.
  let routeModes: Set<TransitMode>
  let stations: [StationMapItem]
  let lineStyle: NetworkLineStyle
  let stationOpacity: Double
  /// A filtered set is capped by a radius and a count before it is asked for,
  /// so it stays readable at a zoom where the unbounded network would not.
  /// When it is what is being drawn, the zoom fade does not apply to it.
  let stationsBypassZoomFade: Bool
  let sharedMobilitySources: [SharedMobilityProvider: SharedMobilitySourceStatus]

  func sourceStatus(_ provider: SharedMobilityProvider) -> SharedMobilitySourceStatus {
    sharedMobilitySources[provider] ?? SharedMobilitySourceStatus(state: .unavailable)
  }

  /// What the annotations actually render at.
  var resolvedStationOpacity: Double {
    stationsBypassZoomFade ? 1 : stationOpacity
  }

  static let empty = NetworkMapSnapshot(
    routes: [],
    routesGeneration: 0,
    routeModes: [],
    stations: [],
    lineStyle: NetworkLineStyle(opacity: 1, width: 3),
    stationOpacity: 1,
    stationsBypassZoomFade: false,
    sharedMobilitySources: [:]
  )

  static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.routesGeneration == rhs.routesGeneration && lhs.routeModes == rhs.routeModes
      && lhs.lineStyle == rhs.lineStyle
      && lhs.stationOpacity == rhs.stationOpacity
      && lhs.stationsBypassZoomFade == rhs.stationsBypassZoomFade
      && lhs.stations == rhs.stations
      && lhs.sharedMobilitySources == rhs.sharedMobilitySources
  }
}

enum NetworkMapLoadingState: Sendable, Equatable {
  case idle
  case loading
  case loaded
  case failed(ViaError)
}

struct NetworkMapState: Sendable, Equatable {
  var snapshot: NetworkMapSnapshot
  var loading: NetworkMapLoadingState

  static let idle = NetworkMapState(snapshot: .empty, loading: .idle)
}

extension NetworkViewport {
  /// Annotations are up to 140 pt wide and Paris stations sit ~500 m apart, so a
  /// viewport wider than this packs labels closer than they can be read:
  /// they stay out until the map is zoomed past it, then fade in over a band
  /// wide enough that a pinch reads as a fade rather than a pop.
  private static let fullyVisibleStationSpanMeters = 1_000.0
  private static let maximumStationSpanMeters = 1_600.0

  /// Past this every nearby vehicle group uses the broad overview grid. Closer
  /// zooms keep sparse vehicles individual and only collapse dense piles.
  private static let groupedSharedMobilitySpanMeters = 850.0

  var showsStations: Bool {
    maximumSpanMeters < Self.maximumStationSpanMeters
  }

  var groupsSharedMobility: Bool {
    maximumSpanMeters > Self.groupedSharedMobilitySpanMeters
  }

  /// A filtered nearby set can remain visible beyond the normal station
  /// threshold, but its full labels cannot: at overview scale they collapse
  /// to symbols, then regain their detailed cards as the traveller zooms in.
  var usesCompactStationAnnotations: Bool {
    maximumSpanMeters > Self.fullyVisibleStationSpanMeters
  }

  var stationOpacity: Double {
    let span = maximumSpanMeters
    guard span > Self.fullyVisibleStationSpanMeters else { return 1 }
    guard span < Self.maximumStationSpanMeters else { return 0 }
    // Quantized for the same reason as TransitLineVisibility: each distinct
    // value republishes the snapshot and rebuilds the annotations.
    return TransitLineVisibility.quantized(
      1 - (span - Self.fullyVisibleStationSpanMeters)
        / (Self.maximumStationSpanMeters - Self.fullyVisibleStationSpanMeters),
      step: 0.1
    )
  }

  var lineStyle: NetworkLineStyle {
    NetworkLineStyle(
      opacity: TransitLineVisibility.opacity(for: maximumSpanMeters),
      width: TransitLineVisibility.lineWidth(for: maximumSpanMeters)
    )
  }

  var transitMapViewport: TransitMapViewport {
    TransitMapViewport(
      latitudeDelta: latitudeDelta,
      longitudeDelta: longitudeDelta,
      width: width,
      height: height,
      laneSpacingPoints: TransitLineVisibility.laneSpacing(for: maximumSpanMeters)
    )
  }
}
