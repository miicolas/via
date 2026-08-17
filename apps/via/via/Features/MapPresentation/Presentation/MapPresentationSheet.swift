import SwiftUI

struct MapPresentationSheet: View {
    let model: MapPresentationModel
    let authViewModel: AuthSessionViewModel
    let account: AccountModel
    let makeDeparturesViewModel: (StationID) -> DeparturesViewModel
    let nearbyStations: NearbyStationsViewModel
    let makeSavedPlacePicker: () -> SavedPlacePickerViewModel
    let isLargeScreen: Bool

    var body: some View {
        content
            .adaptiveSheetPresentation(
                compactDetents: MapPresentationSheetLayout.mainCompactDetents(
                    for: model.state.screen
                ),
                wideDetents: MapPresentationSheetLayout.wideDetents,
                selection: selectedDetent,
                isLargeScreen: isLargeScreen
            )
            .sheet(item: presentedSheet) { route in
                switch route {
                case .journeys:
                    JourneyResultsSheet(
                        model: model,
                        isLargeScreen: isLargeScreen
                    )
                }
            }
    }

    private var presentedSheet: Binding<MapPresentationSheetRoute?> {
        Binding(
            get: { model.state.presentedSheet },
            set: { route in
                guard route == nil else { return }
                model.send(.closeJourneys)
            }
        )
    }

    @ViewBuilder
    private var content: some View {
        switch model.state.screen {
        case .planner:
            MapSearchSheet(
                model: model,
                authViewModel: authViewModel,
                account: account,
                nearbyStations: nearbyStations,
                makeSavedPlacePicker: makeSavedPlacePicker
            )

        case .station(let station):
            StationDeparturesView(
                station: station,
                viewModel: makeDeparturesViewModel(station.id),
                account: account,
                onClose: { model.send(.closeStation) }
            )
            .id(station.id)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.background)
        }
    }

    private var selectedDetent: Binding<PresentationDetent> {
        Binding(
            get: {
                MapPresentationSheetLayout.presentedDetent(
                    model.state.selectedDetent,
                    isLargeScreen: isLargeScreen
                )
            },
            set: { model.send(.detentChanged($0)) }
        )
    }

}

#Preview {
    let dependencies = PreviewDependencies()

    MapPresentationSheet(
        model: dependencies.mapPresentation,
        authViewModel: dependencies.authSession,
        account: dependencies.account,
        makeDeparturesViewModel: { stationID in
            dependencies.makeDeparturesViewModel(for: stationID)
        },
        nearbyStations: dependencies.nearbyStations,
        makeSavedPlacePicker: dependencies.makeSavedPlacePicker,
        isLargeScreen: false
    )
}
