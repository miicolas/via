import SwiftUI

struct JourneyResultsExpandedView: View {
    let model: MapPresentationModel
    let onCollapse: () -> Void

    var body: some View {
        NavigationStack {
            JourneyAlternativesView(
                state: model.state.journeys,
                selectedJourneyID: model.state.selectedJourneyID,
                onSelect: { model.send(.selectJourney($0)) },
                onRetry: { model.send(.retryJourneys) },
                naturalJourney: model.state.naturalJourney,
                naturalJourneyPrimaryJourneyID: model.state.naturalJourneyPrimaryJourneyID,
                onRetryNatural: { model.send(.retryNaturalJourney) },
                onGo: onCollapse
            )
            .sheetContentVisibility()
            .searchable(
                text: activeSearchText,
                isPresented: isSearchPresented,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: resultSearchPrompt
            )
            .onSubmit(of: .search) {
                model.send(.submitNaturalJourney(activeSearchText.wrappedValue))
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .close) {
                        model.send(.closeJourneys)
                    }
                }
            }
        }
    }

    private var activeSearchText: Binding<String> {
        model.state.isNaturalJourneyActive ? naturalJourneyText : destinationText
    }

    private var resultSearchPrompt: Text {
        Text(model.state.isNaturalJourneyActive ? "Décris un autre trajet" : "Où aller ?")
    }

    private var naturalJourneyText: Binding<String> {
        Binding(
            get: { model.state.naturalJourneyQuery },
            set: { model.send(.naturalJourneyQueryChanged($0)) }
        )
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
                guard !model.state.isNaturalJourneyActive else { return }
                model.send(.focus(.destination))
            }
        )
    }
}

#Preview {
    JourneyResultsExpandedView(
        model: AppDependencies.preview.root.mapPresentation,
        onCollapse: {}
    )
}
