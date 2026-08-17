import MapKit
import SwiftUI

struct NetworkMapView: View {
    let viewModel: NetworkViewModel
    let journeyPresentation: JourneyMapPresentation?
    let stationSelectionEnabled: Bool
    @Binding var position: MapCameraPosition
    @Binding var selectedStation: StationMapItem?
    @Namespace private var mapScope
    @State private var visibleRegion: MKCoordinateRegion = .paris

    init(
        viewModel: NetworkViewModel,
        position: Binding<MapCameraPosition>,
        journeyPresentation: JourneyMapPresentation? = nil,
        stationSelectionEnabled: Bool = true,
        selectedStation: Binding<StationMapItem?> = .constant(nil)
    ) {
        self.viewModel = viewModel
        self.journeyPresentation = journeyPresentation
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

                    if let journeyPresentation {
                        JourneyMapContent(presentation: journeyPresentation)
                    }

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
                .onChange(of: journeyPresentation) { _, presentation in
                    guard let presentation else { return }
                    withAnimation(.easeInOut(duration: 0.45)) {
                        position = .rect(presentation.cameraRect)
                    }
                }
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

                if showsInitialSkeleton {
                    NetworkMapLoadingSkeleton()
                } else if case .loading = viewModel.state.loading {
                    NetworkRefreshPill()
                        .padding(.top, 16)
                        .allowsHitTesting(false)
                }
            }
        }
    }

    private var mapSelection: Binding<StationMapItem?> {
        stationSelectionEnabled ? $selectedStation : .constant(nil)
    }

    private var showsInitialSkeleton: Bool {
        guard viewModel.state.snapshot.routes.isEmpty,
              viewModel.state.snapshot.stations.isEmpty else { return false }

        return switch viewModel.state.loading {
        case .idle, .loading:
            true
        case .loaded, .failed:
            false
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
