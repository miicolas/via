import SwiftUI

struct MapSearchSheet: View {
    let model: MapPresentationModel
    let authViewModel: AuthSessionViewModel
    let account: AccountModel
    let onboarding: OnboardingModel
    let nearbyStations: NearbyStationsViewModel
    let makeSavedPlacePicker: () -> SavedPlacePickerViewModel

    @State private var isAccountPresented = false
    @State private var editedPlaceRole: SavedPlace.Role?

    var body: some View {
        NavigationStack {
            content
                // Keep the first row clear of the sheet's drag indicator.
                .padding(.top, 16)
                .sheetContentVisibility()
                .searchable(
                    text: searchText,
                    isPresented: isSearchPresented,
                    prompt: searchPrompt
                )
                .onSubmit(of: .search) {
                    model.send(.submitNaturalJourney(searchText.wrappedValue))
                }
                .toolbarVisibility(.hidden, for: .navigationBar)
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
                    AccountView(
                        authViewModel: authViewModel,
                        account: account,
                        onboarding: onboarding,
                        makeSavedPlacePicker: makeSavedPlacePicker
                    )
                }
                .savedPlacePickerSheet(
                    role: $editedPlaceRole,
                    anchor: locatedCoordinate,
                    account: account,
                    makeViewModel: makeSavedPlacePicker
                )
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
            if let activeField = model.state.activeField {
                PlaceSuggestionsView(
                    search: model.state.search,
                    recentSearches: account.recentSearches,
                    activeField: activeField,
                    location: model.state.location,
                    naturalJourneyQuery: activeQuery,
                    onSubmitNaturalJourney: { model.send(.submitNaturalJourney($0)) },
                    onSelectResult: { model.send(.selectResult($0)) },
                    onSelectRecent: { model.send(.selectRecent($0)) },
                    onRemoveRecent: { model.send(.removeRecent($0)) },
                    onUseCurrentLocation: { model.send(.useCurrentLocation) },
                    onRetry: { model.send(.retrySearch) }
                )
            } else {
                MapHomeView(
                    home: account.place(for: .home),
                    work: account.place(for: .work),
                    favoritePlaces: account.places.filter { $0.role == .favorite },
                    favoriteStations: account.favorites,
                    recentSearches: account.recentSearches,
                    location: model.state.location,
                    nearby: nearbyStations,
                    onSelectPlace: { model.send(.selectSavedPlace($0)) },
                    onSelectFavoriteStation: { model.send(.selectFavorite($0)) },
                    onAddPlace: { editedPlaceRole = $0 },
                    onRemovePlace: { account.removePlace(id: $0.id) },
                    onRemoveFavoriteStation: { account.removeFavorite(stationID: $0.stationID) },
                    onSelectRecent: { model.send(.selectRecent($0)) },
                    onRemoveRecent: { model.send(.removeRecent($0)) },
                    onOpenStation: { model.send(.openStation($0)) }
                )
            }

        case .station:
            Color.clear
        }
    }

    private var locatedCoordinate: GeoCoordinate? {
        guard case .located(let coordinate) = model.state.location else { return nil }
        return coordinate
    }

    private var activeQuery: String {
        guard let field = model.state.activeField else { return "" }
        return model.state.draft.query(for: field)
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
        case .destination, nil: Text("Où aller et pour quand ?")
        }
    }
}

#Preview("Recherche classique") {
    @Previewable @State var query = "Châtelet"
    @Previewable @State var isSearching = true

    NavigationStack {
        PlaceSuggestionsView(
            search: .loaded(.mapPreview),
            recentSearches: [],
            activeField: .destination,
            location: .located(.init(latitude: 48.8566, longitude: 2.3522)),
            naturalJourneyQuery: "",
            onSubmitNaturalJourney: { _ in },
            onSelectResult: { _ in },
            onSelectRecent: { _ in },
            onRemoveRecent: { _ in },
            onUseCurrentLocation: {},
            onRetry: {}
        )
        .searchable(
            text: $query,
            isPresented: $isSearching,
            prompt: "Où aller et pour quand ?"
        )
        .toolbarVisibility(.hidden, for: .navigationBar)
        .toolbar {
            DefaultToolbarItem(kind: .search, placement: .bottomBar)
        }
    }
}
