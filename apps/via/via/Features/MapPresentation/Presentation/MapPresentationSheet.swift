import SwiftUI

struct MapPresentationSheet: View {
    let model: MapPresentationModel
    let authViewModel: AuthSessionViewModel
    let account: AccountModel
    let naturalJourneyViewModel: NaturalJourneyViewModel
    let makeDeparturesViewModel: (StationID) -> DeparturesViewModel

    var body: some View {
        content
            .sheetTabVisibilityRoot()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .presentationDetents(detents, selection: selectedDetent)
            .presentationBackgroundInteraction(.enabled(upThrough: .large))
            .presentationContentInteraction(.resizes)
            .presentationDragIndicator(.visible)
            .interactiveDismissDisabled()
            .sheet(item: presentedSheet) { route in
            switch route {
            case .journeys:
                JourneyResultsSheet(model: model)
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
                naturalJourneyViewModel: naturalJourneyViewModel
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

    private var detents: Set<PresentationDetent> {
        switch model.state.screen {
        case .planner(.planning), .planner(.results):
            [MapPresentationState.collapsedDetent]
        case .planner:
            [MapPresentationState.collapsedDetent, MapPresentationState.searchDetent, .large]
        case .station:
            [MapPresentationState.collapsedDetent, .medium, .large]
        }
    }

    private var selectedDetent: Binding<PresentationDetent> {
        Binding(
            get: { model.state.selectedDetent },
            set: { model.send(.detentChanged($0)) }
        )
    }

}

#Preview {
    let dependencies = AppDependencies.preview

    Color.blue
        .sheet(isPresented: .constant(true)) {
            MapPresentationSheet(
                model: dependencies.root.mapPresentation,
                authViewModel: dependencies.authSession,
                account: dependencies.root.account,
                naturalJourneyViewModel: dependencies.root.naturalJourney,
                makeDeparturesViewModel: dependencies.root.makeDeparturesViewModel
            )
        }
}
