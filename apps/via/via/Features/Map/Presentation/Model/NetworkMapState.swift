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
    let stations: [StationMapItem]
    let lineStyle: NetworkLineStyle
    let stationOpacity: Double

    static let empty = NetworkMapSnapshot(
        routes: [],
        stations: [],
        lineStyle: NetworkLineStyle(opacity: 1, width: 3),
        stationOpacity: 1
    )
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
    private static let fullyVisibleStationSpanMeters = 1_700.0
    private static let maximumStationSpanMeters = 2_100.0

    var showsStations: Bool {
        maximumSpanMeters < Self.maximumStationSpanMeters
    }

    var stationOpacity: Double {
        let span = maximumSpanMeters
        guard span > Self.fullyVisibleStationSpanMeters else { return 1 }
        guard span < Self.maximumStationSpanMeters else { return 0 }
        return 1 - (span - Self.fullyVisibleStationSpanMeters) /
            (Self.maximumStationSpanMeters - Self.fullyVisibleStationSpanMeters)
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
