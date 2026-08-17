import SwiftUI
import MapKit

extension MKCoordinateRegion {
    static let paris = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 48.8566, longitude: 2.3522),
        latitudinalMeters: 1_000,
        longitudinalMeters: 1_000
    )
}

struct RootView: View {
    @State private var isMapSheetPresented = true
    @State private var presentation: MapPresentationModel
    @State private var networkViewModel: NetworkViewModel
    @State private var mapPosition = MapCameraPosition.region(.paris)
    @State private var isLargeScreen = false
    private let authViewModel: AuthSessionViewModel
    private let dependencies: RootDependencies

    init(
        dependencies: RootDependencies,
        authViewModel: AuthSessionViewModel
    ) {
        _networkViewModel = State(initialValue: dependencies.networkMap)
        _presentation = State(initialValue: dependencies.mapPresentation)
        self.authViewModel = authViewModel
        self.dependencies = dependencies
    }
    
    var body: some View {
        Group {
            switch presentation.state.location {
            case .located:
                appContent
            case .idle, .locating, .failed:
                LocationRequiredView(
                    state: presentation.state.location,
                    onRequestLocation: {
                        presentation.send(.requestLocation)
                    }
                )
            }
        }
        .task {
            presentation.send(.requestLocation)
        }
    }

    private var appContent: some View {
        NetworkMapView(
            viewModel: networkViewModel,
            position: $mapPosition,
            journeyPresentation: presentation.state.mapPresentation,
            stationSelectionEnabled: presentation.state.stationSelectionEnabled,
            selectedStation: mapSelection
        )
        .sheet(isPresented: $isMapSheetPresented) {
            MapPresentationSheet(
                model: presentation,
                authViewModel: authViewModel,
                account: dependencies.account,
                makeDeparturesViewModel: dependencies.makeDeparturesViewModel,
                nearbyStations: dependencies.nearbyStations,
                makeSavedPlacePicker: dependencies.makeSavedPlacePicker,
                isLargeScreen: isLargeScreen
            )
        }
        .onGeometryChange(for: Bool.self) { geometry in
            geometry.size.width > 600
        } action: { isLargeScreen in
            updateLayout(isLargeScreen: isLargeScreen)
        }
    }

    private var mapSelection: Binding<StationMapItem?> {
        Binding(
            get: { presentation.state.selectedStation },
            set: { presentation.send(.selectMapStation($0)) }
        )
    }

    private func updateLayout(isLargeScreen newValue: Bool) {
        guard newValue != isLargeScreen else { return }

        let currentDetent = presentation.state.selectedDetent
        let nextDetent = MapPresentationSheetLayout.transitionedDetent(
            currentDetent,
            isLargeScreen: newValue
        )
        if nextDetent != currentDetent {
            presentation.send(.detentChanged(nextDetent))
        }
        isLargeScreen = newValue
    }
}
