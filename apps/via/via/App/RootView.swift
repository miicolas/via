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
    @State private var naturalJourneyViewModel: NaturalJourneyViewModel
    @State private var mapPosition = MapCameraPosition.region(.paris)
    private let authViewModel: AuthSessionViewModel
    private let account: AccountModel
    private let makeDeparturesViewModel: (StationID) -> DeparturesViewModel

    init(
        dependencies: RootDependencies,
        authViewModel: AuthSessionViewModel
    ) {
        _networkViewModel = State(initialValue: dependencies.networkMap)
        _presentation = State(initialValue: dependencies.mapPresentation)
        _naturalJourneyViewModel = State(initialValue: dependencies.naturalJourney)
        self.authViewModel = authViewModel
        account = dependencies.account
        makeDeparturesViewModel = dependencies.makeDeparturesViewModel
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
                account: account,
                naturalJourneyViewModel: naturalJourneyViewModel,
                makeDeparturesViewModel: makeDeparturesViewModel
            )
        }
    }

    private var mapSelection: Binding<StationMapItem?> {
        Binding(
            get: { presentation.state.selectedStation },
            set: { presentation.send(.selectMapStation($0)) }
        )
    }
}

#Preview {
    let dependencies = AppDependencies.preview
    RootView(
        dependencies: dependencies.root,
        authViewModel: dependencies.authSession
    )
}
