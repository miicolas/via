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
    @State private var presentation = MapPresentationState()
    @State private var networkViewModel: NetworkViewModel
    private let authViewModel: AuthSessionViewModel
    private let favoriteStations: any FavoriteStationRepository
    private let transportPreferences: any TransportPreferencesRepository
    private let makeDeparturesViewModel: (StationID) -> DeparturesViewModel

    init(
        networkViewModel: NetworkViewModel,
        authViewModel: AuthSessionViewModel,
        favoriteStations: any FavoriteStationRepository,
        transportPreferences: any TransportPreferencesRepository,
        makeDeparturesViewModel: @escaping (StationID) -> DeparturesViewModel
    ) {
        _networkViewModel = State(initialValue: networkViewModel)
        self.authViewModel = authViewModel
        self.favoriteStations = favoriteStations
        self.transportPreferences = transportPreferences
        self.makeDeparturesViewModel = makeDeparturesViewModel
    }
    
    var body: some View {
        NetworkMapView(
            viewModel: networkViewModel,
            selectedStation: mapSelection
        )
        .sheet(isPresented: $isMapSheetPresented) {
            MapPresentationSheet(
                state: $presentation,
                authViewModel: authViewModel,
                favoriteStations: favoriteStations,
                transportPreferences: transportPreferences,
                makeDeparturesViewModel: makeDeparturesViewModel
            )
        }
    }

    private var mapSelection: Binding<StationMapItem?> {
        Binding(
            get: { presentation.selectedStation },
            set: { presentation.selectMapStation($0) }
        )
    }
}

#Preview {
    RootView(
        networkViewModel: NetworkViewModel(repository: InMemoryNetworkRepository.mapPreview),
        authViewModel: .preview,
        favoriteStations: AppDependencies.preview.favoriteStations,
        transportPreferences: AppDependencies.preview.transportPreferences,
        makeDeparturesViewModel: {
            DeparturesViewModel(
                stationID: $0,
                repository: InMemoryDeparturesRepository()
            )
        }
    )
}
