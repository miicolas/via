import SwiftUI

struct MapPresentationSheet: View {
    @Binding var state: MapPresentationState
    let authViewModel: AuthSessionViewModel
    let account: AccountModel
    let makeDeparturesViewModel: (StationID) -> DeparturesViewModel

    var body: some View {
        content
            .presentationDetents(detents, selection: selectedDetent)
            .presentationBackgroundInteraction(.enabled(upThrough: .large))
            .presentationContentInteraction(.resizes)
            .presentationDragIndicator(.visible)
            .interactiveDismissDisabled()
    }

    private var content: some View {
        ZStack {
            MapSearchSheet(
                text: $state.searchText,
                authViewModel: authViewModel,
                account: account
            )

            if let station = state.destination.station {
                StationDeparturesView(
                    station: station,
                    viewModel: makeDeparturesViewModel(station.id),
                    account: account,
                    onClose: { state.showSearch() }
                )
                .id(station.id)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.background)
                .zIndex(1)
            }
        }
    }

    private var detents: Set<PresentationDetent> {
        switch state.destination {
        case .search:
            [MapPresentationState.collapsedDetent, MapPresentationState.searchDetent, .large]
        case .station:
            [MapPresentationState.collapsedDetent, .medium, .large]
        }
    }

    private var selectedDetent: Binding<PresentationDetent> {
        Binding(
            get: { state.selectedDetent },
            set: { state.selectDetent($0) }
        )
    }

}

#Preview {
    @Previewable @State var state = MapPresentationState()

    Color.blue
        .sheet(isPresented: .constant(true)) {
            MapPresentationSheet(
                state: $state,
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
}
