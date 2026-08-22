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
    let stations: [StationMapItem]
    let lineStyle: NetworkLineStyle
    let stationOpacity: Double

    static let empty = NetworkMapSnapshot(
        routes: [],
        routesGeneration: 0,
        stations: [],
        lineStyle: NetworkLineStyle(opacity: 1, width: 3),
        stationOpacity: 1
    )

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.routesGeneration == rhs.routesGeneration &&
            lhs.lineStyle == rhs.lineStyle &&
            lhs.stationOpacity == rhs.stationOpacity &&
            lhs.stations == rhs.stations
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
    /// Annotations are 200 pt wide and Paris stations sit ~500 m apart, so a
    /// viewport wider than this packs labels closer than they can be read:
    /// they stay out until the map is zoomed past it, then fade in over a band
    /// wide enough that a pinch reads as a fade rather than a pop.
    private static let fullyVisibleStationSpanMeters = 1_000.0
    private static let maximumStationSpanMeters = 1_600.0

    var showsStations: Bool {
        maximumSpanMeters < Self.maximumStationSpanMeters
    }

    var stationOpacity: Double {
        let span = maximumSpanMeters
        guard span > Self.fullyVisibleStationSpanMeters else { return 1 }
        guard span < Self.maximumStationSpanMeters else { return 0 }
        // Quantized for the same reason as TransitLineVisibility: each distinct
        // value republishes the snapshot and rebuilds the annotations.
        return TransitLineVisibility.quantized(
            1 - (span - Self.fullyVisibleStationSpanMeters) /
                (Self.maximumStationSpanMeters - Self.fullyVisibleStationSpanMeters),
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
