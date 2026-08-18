import MapKit
import SwiftUI

struct NetworkMapView: View {
    let viewModel: NetworkViewModel
    let stationSelectionEnabled: Bool
    @Binding var position: MapCameraPosition
    @Binding var selectedStation: StationMapItem?
    @Namespace private var mapScope
    @State private var visibleRegion: MKCoordinateRegion = .paris

    init(
        viewModel: NetworkViewModel,
        position: Binding<MapCameraPosition>,
        stationSelectionEnabled: Bool = true,
        selectedStation: Binding<StationMapItem?> = .constant(nil)
    ) {
        self.viewModel = viewModel
        self.stationSelectionEnabled = stationSelectionEnabled
        _position = position
        _selectedStation = selectedStation
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                Map(
                    position: $position,
                    selection: mapSelection,
                    scope: mapScope
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
                            coordinate: station.coordinate.clLocationCoordinate,
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
                    MapUserLocationButton(scope: mapScope)
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

    private var mapSelection: Binding<StationMapItem?> {
        stationSelectionEnabled ? $selectedStation : .constant(nil)
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
