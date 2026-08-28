import MapKit
import SwiftUI

struct NetworkMapView: View {
  let viewModel: NetworkViewModel
  let nearby: NearbyStationsModel?
  let stationSelectionEnabled: Bool
  let journeyPresentation: JourneyMapPresentation?
  let highlightedJourneySegmentID: String?
  @Binding var position: MapCameraPosition
  @Binding var selectedStation: StationMapItem?
  @Namespace private var mapScope
  @State private var visibleRegion: MKCoordinateRegion = .paris
  /// A filter change reframes on the *results*, which land a beat later. Armed
  /// here, spent when they arrive.
  @State private var awaitsCameraFit = false
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  init(
    viewModel: NetworkViewModel,
    position: Binding<MapCameraPosition>,
    nearby: NearbyStationsModel? = nil,
    stationSelectionEnabled: Bool = true,
    journeyPresentation: JourneyMapPresentation? = nil,
    highlightedJourneySegmentID: String? = nil,
    selectedStation: Binding<StationMapItem?> = .constant(nil)
  ) {
    self.viewModel = viewModel
    self.nearby = nearby
    self.stationSelectionEnabled = stationSelectionEnabled
    self.journeyPresentation = journeyPresentation
    self.highlightedJourneySegmentID = highlightedJourneySegmentID
    _position = position
    _selectedStation = selectedStation
  }

  var body: some View {
    @Bindable var viewModel = viewModel

    GeometryReader { geometry in
      ZStack(alignment: .top) {
        Map(
          position: $position,
          selection: mapSelection,
          scope: mapScope
        ) {
          let snapshot = viewModel.state.snapshot
          if snapshot.lineStyle.opacity * networkDimming > 0 {
            TransitRouteMapContent(
              routes: snapshot.routes,
              opacity: snapshot.lineStyle.opacity * networkDimming,
              lineWidth: snapshot.lineStyle.width
            )
          }

          if let journeyPresentation {
            JourneyRouteMapContent(
              presentation: journeyPresentation,
              highlightedSegmentID: highlightedJourneySegmentID
            )
          }

          UserAnnotation()

          ForEach(snapshot.stations) { station in
            Annotation(
              station.name,
              coordinate: station.coordinate.clLocationCoordinate,
              anchor: .bottom
            ) {
              Group {
                if let cluster = station.sharedMobilityCluster {
                  SharedMobilityClusterAnnotationView(cluster: cluster)
                } else if let sharedMobility = station.sharedMobility {
                  SharedMobilityAnnotationView(
                    item: sharedMobility,
                    isCompact: annotationIsCompact(in: geometry.size)
                  )
                } else if let bikeStation = station.bikeStation {
                  BikeStationAnnotationView(
                    station: bikeStation,
                    isCompact: annotationIsCompact(in: geometry.size)
                  )
                } else {
                  StationAnnotationView(
                    item: station,
                    visibleModes: snapshot.routeModes,
                    isCompact: annotationIsCompact(in: geometry.size)
                  )
                }
              }
              .opacity(snapshot.resolvedStationOpacity * stationDimming)
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
          MapCompass(scope: mapScope)
          MapUserLocationButton(scope: mapScope)
        }
        .animation(
          reduceMotion ? nil : .smooth(duration: 0.18),
          value: viewModel.state.snapshot.stations
        )
        .onMapCameraChange(frequency: .continuous) { context in
          visibleRegion = context.region
          viewModel.viewportChanged(
            to: context.region.networkViewport(size: geometry.size),
            phase: .continuous
          )
        }
        .onMapCameraChange(frequency: .onEnd) { context in
          visibleRegion = context.region
          // The traveller moved the map themselves: a reframe still owed to an
          // earlier filter is no longer wanted.
          awaitsCameraFit = false
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
        .onChange(of: viewModel.stationFilter) { _, filter in
          // Arm only for a filter that has something to frame. Clearing one
          // must not move the camera at all.
          awaitsCameraFit = filter.isActive
        }
        .onChange(of: nearby?.results) { _, _ in
          fitCameraToResultsIfWorthwhile()
        }
        NetworkMapStatusView(
          loading: viewModel.state.loading,
          hasContent: !viewModel.state.snapshot.routes.isEmpty
            || !viewModel.state.snapshot.stations.isEmpty,
          onRetry: viewModel.retry
        )
        .padding(.top, 8)
        .padding(.horizontal, 12)

        if sharedMobilitySourcesUnavailable {
          EmptyStateView(.sharedMobilityUnavailable) {
            RetryButton(action: viewModel.retry)
              .primaryAction()
          }
          .background(.regularMaterial, in: .rect(cornerRadius: 24))
          .padding(.horizontal, 24)
          .frame(maxHeight: .infinity)
        } else if sharedMobilityHasNoResults {
          EmptyStateView(.noSharedMobilityInArea)
            .background(.regularMaterial, in: .rect(cornerRadius: 24))
            .padding(.horizontal, 24)
            .frame(maxHeight: .infinity)
            .allowsHitTesting(false)
        }
      }
      .mapScope(mapScope)
      // Outside the ZStack rather than an overlay on the Map: the status view
      // and the empty states are later siblings, and a full-width sibling drawn
      // above the map would otherwise take the taps meant for this button.
      .overlay(alignment: .topLeading) {
        StationMapFilterMenu(filter: $viewModel.stationFilter)
          // The map control region already starts below the top safe area.
          // Adding it again places this button one status-bar height below
          // MapKit's location control.
          .padding(.top, 8)
          .padding(.leading, geometry.safeAreaInsets.leading + 8)
          .zIndex(1)
      }
    }
  }

  /// Never widens and never fires on a pan: `MapCameraFit` refuses anything
  /// that is not a decisive tightening, and this is only armed by a filter.
  private func fitCameraToResultsIfWorthwhile() {
    guard awaitsCameraFit else { return }
    awaitsCameraFit = false
    guard let bounds = nearby?.resultsBounds,
          let region = MapCameraFit.fittedRegion(for: bounds, in: visibleRegion)
    else { return }
    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.45)) {
      position = .region(region)
    }
  }

  private var mapSelection: Binding<StationMapItem?> {
    stationSelectionEnabled ? $selectedStation : .constant(nil)
  }

  private func annotationIsCompact(in size: CGSize) -> Bool {
    visibleRegion.networkViewport(size: size).usesCompactStationAnnotations
  }

  private var sharedMobilitySourcesUnavailable: Bool {
    guard viewModel.state.loading == .loaded,
          viewModel.stationFilter.wantsSharedMobility
    else { return false }

    let statuses = requestedSharedMobilityProviders.map {
      viewModel.state.snapshot.sourceStatus($0)
    }
    guard !statuses.isEmpty,
          viewModel.state.snapshot.sharedMobilitySources.isEmpty == false
    else { return false }
    return statuses.allSatisfy { !$0.isAvailable }
  }

  private var sharedMobilityHasNoResults: Bool {
    viewModel.state.loading == .loaded
      && viewModel.stationFilter.wantsSharedMobility
      && !sharedMobilitySourcesUnavailable
      && viewModel.state.snapshot.resolvedStationOpacity > 0
      && viewModel.state.snapshot.stations.isEmpty
  }

  private var requestedSharedMobilityProviders: Set<SharedMobilityProvider> {
    viewModel.stationFilter.requestedSharedMobilityProviders
  }

  /// A selected journey owns the map: the rest of the network drops to a
  /// watermark so the chosen route is the only thing in full colour.
  private var networkDimming: Double {
    journeyPresentation == nil ? 1 : 0.12
  }

  private var stationDimming: Double {
    journeyPresentation == nil ? 1 : 0.25
  }
}

extension MKCoordinateRegion {
  fileprivate func networkViewport(size: CGSize) -> NetworkViewport {
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
