import MapKit
import SwiftUI

struct NetworkMapView: View {
    let viewModel: NetworkViewModel
    let initialRegion: MKCoordinateRegion
    @Binding var selectedStation: StationMapItem?
    @State private var visibleRegion: MKCoordinateRegion
    @State private var routeLayoutRegion: MKCoordinateRegion
    @State private var positionedRoutes: [NetworkRoute] = []

    init(
        viewModel: NetworkViewModel,
        initialRegion: MKCoordinateRegion = .paris,
        selectedStation: Binding<StationMapItem?> = .constant(nil)
    ) {
        self.viewModel = viewModel
        self.initialRegion = initialRegion
        _selectedStation = selectedStation
        _visibleRegion = State(initialValue: initialRegion)
        _routeLayoutRegion = State(initialValue: initialRegion)
    }

    var body: some View {
        GeometryReader { geometry in
            let positioningID = RoutePositioningID(
                layoutRevision: viewModel.routeLayoutRevision,
                latitudeDelta: routeLayoutRegion.span.latitudeDelta,
                longitudeDelta: routeLayoutRegion.span.longitudeDelta,
                width: Double(geometry.size.width),
                height: Double(geometry.size.height)
            )

            Map(
                initialPosition: .region(initialRegion),
                selection: $selectedStation
            ) {
                if visibleRegion.transitLineOpacity > 0 {
                    TransitRouteMapContent(
                        routes: positionedRoutes,
                        opacity: visibleRegion.transitLineOpacity,
                        lineWidth: visibleRegion.transitLineWidth
                    )
                }

                UserAnnotation()

                if visibleRegion.showsStationAnnotations {
                    ForEach(visibleStations) { station in
                        Annotation(
                            station.name,
                            coordinate: CLLocationCoordinate2D(
                                latitude: station.coordinate.latitude,
                                longitude: station.coordinate.longitude
                            ),
                            anchor: .bottom
                        ) {
                            StationAnnotationView(item: station)
                                .opacity(visibleRegion.stationAnnotationOpacity)
                                .transition(.opacity)
                        }
                        .annotationTitles(.hidden)
                        .tag(station)
                    }
                }
            }
            .mapStyle(
                .standard(
                    emphasis: .muted,
                    pointsOfInterest: .excludingAll
                )
            )
            .mapControls {
                MapUserLocationButton()
            }
            .animation(.easeInOut(duration: 0.18), value: viewModel.stationMapItems)
            .onMapCameraChange(frequency: .continuous) { context in
                visibleRegion = context.region
            }
            .onMapCameraChange(frequency: .onEnd) { context in
                visibleRegion = context.region
                routeLayoutRegion = context.region
                loadStations(in: context.region)
            }
            .task {
                viewModel.load()
                loadStations(in: initialRegion)
            }
            .task(id: positioningID) {
                await updatePositionedRoutes(viewportSize: geometry.size)
            }
        }
    }

    private var visibleStations: [StationMapItem] {
        viewModel.stationMapItems.filter { station in
            visibleRegion.contains(station.coordinate)
        }
    }

    private func loadStations(in region: MKCoordinateRegion) {
        guard region.showsStationAnnotations else { return }
        viewModel.viewportChanged(to: region.geoBounds)
    }

    private func updatePositionedRoutes(viewportSize: CGSize) async {
        guard let layout = viewModel.routeLayout else {
            positionedRoutes = []
            return
        }
        let viewport = TransitMapViewport(
            latitudeDelta: routeLayoutRegion.span.latitudeDelta,
            longitudeDelta: routeLayoutRegion.span.longitudeDelta,
            width: Double(viewportSize.width),
            height: Double(viewportSize.height),
            laneSpacingPoints: routeLayoutRegion.transitLineLaneSpacing
        )
        let routes = await Task.detached(priority: .userInitiated) {
            layout.positioned(in: viewport)
        }.value
        guard !Task.isCancelled else { return }
        positionedRoutes = routes
    }
}

private struct RoutePositioningID: Hashable {
    let layoutRevision: Int
    let latitudeDelta: Double
    let longitudeDelta: Double
    let width: Double
    let height: Double
}

private extension MKCoordinateRegion {
    static let fullyVisibleStationAnnotationSpanMeters = 1_100.0
    static let maximumStationAnnotationSpanMeters = 1_400.0

    var stationAnnotationOpacity: Double {
        let span = maximumSpanMeters
        guard span > Self.fullyVisibleStationAnnotationSpanMeters else { return 1 }
        guard span < Self.maximumStationAnnotationSpanMeters else { return 0 }
        return 1 - (span - Self.fullyVisibleStationAnnotationSpanMeters) /
            (Self.maximumStationAnnotationSpanMeters - Self.fullyVisibleStationAnnotationSpanMeters)
    }

    var showsStationAnnotations: Bool {
        maximumSpanMeters < Self.maximumStationAnnotationSpanMeters
    }

    var transitLineOpacity: Double {
        TransitLineVisibility.opacity(for: maximumSpanMeters)
    }

    var transitLineWidth: Double {
        TransitLineVisibility.lineWidth(for: maximumSpanMeters)
    }

    var transitLineLaneSpacing: Double {
        TransitLineVisibility.laneSpacing(for: maximumSpanMeters)
    }

    var maximumSpanMeters: Double {
        let latitudeMeters = span.latitudeDelta * 111_000
        let longitudeMeters = span.longitudeDelta * 111_000 * cos(center.latitude * .pi / 180)
        return max(latitudeMeters, longitudeMeters)
    }

    func contains(_ coordinate: GeoCoordinate) -> Bool {
        let latitudeRadius = span.latitudeDelta / 2
        let longitudeRadius = span.longitudeDelta / 2
        return coordinate.latitude >= center.latitude - latitudeRadius &&
            coordinate.latitude <= center.latitude + latitudeRadius &&
            coordinate.longitude >= center.longitude - longitudeRadius &&
            coordinate.longitude <= center.longitude + longitudeRadius
    }

    var geoBounds: GeoBounds {
        let latitudeRadius = span.latitudeDelta / 2
        let longitudeRadius = span.longitudeDelta / 2
        return GeoBounds(
            minLatitude: max(-90, center.latitude - latitudeRadius),
            maxLatitude: min(90, center.latitude + latitudeRadius),
            minLongitude: max(-180, center.longitude - longitudeRadius),
            maxLongitude: min(180, center.longitude + longitudeRadius)
        )
    }
}
