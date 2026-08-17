import SwiftUI

struct JourneyResultsSheet: View {
    let model: MapPresentationModel

    @State private var detent = MapPresentationState.searchDetent

    var body: some View {
        NavigationStack {
            JourneyAlternativesView(
                state: model.state.journeys,
                selectedJourneyID: model.state.selectedJourneyID,
                onSelect: { model.send(.selectJourney($0)) },
                onRetry: { model.send(.retryJourneys) },
                onGo: { detent = MapPresentationState.searchDetent }
            )
            .sheetTabVisibility()
            .searchable(
                text: destinationText,
                isPresented: isSearchPresented,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Où aller ?"
            )
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .close) {
                        model.send(.closeJourneys)
                    }
                }
            }
        }
        .presentationDetents(
            [MapPresentationState.searchDetent, .large],
            selection: $detent
        )
        .presentationBackgroundInteraction(.enabled(upThrough: .large))
        .presentationDragIndicator(.visible)
    }

    private var destinationText: Binding<String> {
        Binding(
            get: { model.state.draft.destinationQuery },
            set: { query in
                model.send(.focus(.destination))
                model.send(.queryChanged(.destination, query))
            }
        )
    }

    private var isSearchPresented: Binding<Bool> {
        Binding(
            get: { false },
            set: { presented in
                guard presented else { return }
                model.send(.focus(.destination))
            }
        )
    }
}

#Preview {
    Color.blue
        .sheet(isPresented: .constant(true)) {
            JourneyResultsSheet(model: AppDependencies.preview.root.mapPresentation)
        }
}
