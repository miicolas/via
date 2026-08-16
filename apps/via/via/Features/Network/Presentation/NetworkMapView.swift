import MapKit
import SwiftUI

struct NetworkMapView: View {
    let viewModel: NetworkViewModel
    let initialRegion: MKCoordinateRegion
    @Binding var selectedStation: StationMapItem?
    @State private var visibleRegion: MKCoordinateRegion

    init(
        viewModel: NetworkViewModel,
        initialRegion: MKCoordinateRegion = .paris,
        selectedStation: Binding<StationMapItem?> = .constant(nil)
    ) {
        self.viewModel = viewModel
        self.initialRegion = initialRegion
        _selectedStation = selectedStation
        _visibleRegion = State(initialValue: initialRegion)
    }

    var body: some View {
        GeometryReader { geometry in
            Map(
                initialPosition: .region(initialRegion),
                selection: $selectedStation
            ) {
                let snapshot = viewModel.state.snapshot
                if snapshot.lineStyle.opacity > 0 {
                    TransitRouteMapContent(
                        routes: snapshot.routes,
                        opacity: snapshot.lineStyle.opacity,
                        lineWidth: snapshot.lineStyle.width
                    )
                }

                UserAnnotation()

                ForEach(snapshot.stations) { station in
                    Annotation(
                        station.name,
                        coordinate: CLLocationCoordinate2D(
                            latitude: station.coordinate.latitude,
                            longitude: station.coordinate.longitude
                        ),
                        anchor: .bottom
                    ) {
                        StationAnnotationView(item: station)
                            .opacity(snapshot.stationOpacity)
                            .transition(.opacity)
                    }
                    .annotationTitles(.hidden)
                    .tag(station)
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
            .animation(.easeInOut(duration: 0.18), value: viewModel.state.snapshot.stations)
            .onMapCameraChange(frequency: .continuous) { context in
                visibleRegion = context.region
                viewModel.viewportChanged(
                    to: context.region.networkViewport(size: geometry.size),
                    phase: .continuous
                )
            }
            .onMapCameraChange(frequency: .onEnd) { context in
                visibleRegion = context.region
                viewModel.viewportChanged(
                    to: context.region.networkViewport(size: geometry.size),
                    phase: .ended
                )
            }
            .task(id: geometry.size) {
                viewModel.viewportChanged(
                    to: visibleRegion.networkViewport(size: geometry.size),
                    phase: .ended
                )
            }
        }
    }
}

private extension MKCoordinateRegion {
    func networkViewport(size: CGSize) -> NetworkViewport {
        NetworkViewport(
            center: GeoCoordinate(
                latitude: center.latitude,
                longitude: center.longitude
            ),
            latitudeDelta: span.latitudeDelta,
            longitudeDelta: span.longitudeDelta,
            width: Double(size.width),
            height: Double(size.height)
        )
    }
}
