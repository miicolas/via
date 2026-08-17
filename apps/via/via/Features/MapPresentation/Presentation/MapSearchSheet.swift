import SwiftUI

struct MapSearchSheet: View {
    let model: MapPresentationModel
    let authViewModel: AuthSessionViewModel
    let account: AccountModel
    let naturalJourneyViewModel: NaturalJourneyViewModel

    @State private var isAccountPresented = false
    @State private var isNaturalSearchPresented = false

    var body: some View {
        NavigationStack {
            content
                .sheetTabVisibility()
                .searchable(
                    text: searchText,
                    isPresented: isSearchPresented,
                    prompt: searchPrompt
                )
                .toolbar {
                    DefaultToolbarItem(kind: .search, placement: .bottomBar)

                    ToolbarSpacer(placement: .bottomBar)

                    ToolbarItem(placement: .bottomBar) {
                        Button("Compte", systemImage: "person.crop.circle.fill") {
                            isAccountPresented = true
                        }
                        .labelStyle(.iconOnly)
                    }
                }
                .sheet(isPresented: $isAccountPresented) {
                    AccountView(authViewModel: authViewModel, account: account)
                }
                .sheet(isPresented: $isNaturalSearchPresented) {
                    NaturalJourneySearchView(
                        viewModel: naturalJourneyViewModel,
                        currentLocation: currentLocation
                    )
                }
                .onAppear {
                    model.send(.preparePlanner)
                }
        }
    }

    private var isSearchPresented: Binding<Bool> {
        Binding(
            get: { model.state.activeField != nil },
            set: { presented in
                if presented {
                    if model.state.activeField == nil {
                        model.send(.focus(.destination))
                    }
                } else if model.state.activeField != nil {
                    model.send(.dismissSearch)
                }
            }
        )
    }

    @ViewBuilder
    private var content: some View {
        switch model.state.screen {
        case .planner:
            PlaceSuggestionsView(
                search: model.state.search,
                recentSearches: account.recentSearches,
                activeField: model.state.activeField,
                location: model.state.location,
                onSelectResult: { model.send(.selectResult($0)) },
                onSelectRecent: { model.send(.selectRecent($0)) },
                onRemoveRecent: { model.send(.removeRecent($0)) },
                onUseCurrentLocation: { model.send(.useCurrentLocation) },
                onOpenNaturalSearch: { isNaturalSearchPresented = true },
                onRetry: { model.send(.retrySearch) }
            )

        case .station:
            Color.clear
        }
    }

    private var searchText: Binding<String> {
        Binding(
            get: {
                guard let field = model.state.activeField else {
                    return model.state.draft.destination?.name ?? ""
                }
                return model.state.draft.query(for: field)
            },
            set: { query in
                guard let field = model.state.activeField else { return }
                model.send(.queryChanged(field, query))
            }
        )
    }

    private var searchPrompt: Text {
        switch model.state.activeField {
        case .origin: Text("Ma position ou un lieu")
        case .destination, nil: Text("Où aller ?")
        }
    }

    private var currentLocation: GeoCoordinate? {
        guard case .located(let coordinate) = model.state.location else { return nil }
        return coordinate
    }
}

#Preview {
    let dependencies = AppDependencies.preview

    Color.blue
        .sheet(isPresented: .constant(true)) {
            MapSearchSheet(
                model: dependencies.root.mapPresentation,
                authViewModel: dependencies.authSession,
                account: dependencies.root.account,
                naturalJourneyViewModel: dependencies.root.naturalJourney
            )
            .presentationDetents([.height(95), .fraction(0.45), .large])
        }
}
