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
    private let account: AccountModel
    private let makeDeparturesViewModel: (StationID) -> DeparturesViewModel

    init(
        networkViewModel: NetworkViewModel,
        authViewModel: AuthSessionViewModel,
        account: AccountModel,
        makeDeparturesViewModel: @escaping (StationID) -> DeparturesViewModel
    ) {
        _networkViewModel = State(initialValue: networkViewModel)
        self.authViewModel = authViewModel
        self.account = account
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
                account: account,
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
        account: AppDependencies.preview.account,
        makeDeparturesViewModel: {
            DeparturesViewModel(
                stationID: $0,
                repository: InMemoryDeparturesRepository()
            )
        }
    )
}
