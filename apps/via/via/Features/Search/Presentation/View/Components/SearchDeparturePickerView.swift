import SwiftUI

struct SearchDeparturePickerView: View {
    let viewModel: SearchViewModel
    let savedPlaces: [SavedPlace]
    let savedDestinations: [SavedDestination]
    let selection: SearchDepartureSelection
    let onSelect: (SearchDepartureSelection) -> Void

    @Environment(\.dismiss) private var dismiss

    init(
        viewModel: SearchViewModel,
        savedPlaces: [SavedPlace] = [],
        savedDestinations: [SavedDestination] = [],
        selection: SearchDepartureSelection = .currentLocation,
        onSelect: @escaping (SearchDepartureSelection) -> Void
    ) {
        self.viewModel = viewModel
        self.savedPlaces = savedPlaces
        self.savedDestinations = savedDestinations
        self.selection = selection
        self.onSelect = onSelect
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        NavigationStack {
            List {
                SearchDestinationField(
                    text: $viewModel.departureQuery,
                    prompt: "Station ou adresse",
                    accessibilityLabel: "Point de départ",
                    clearAccessibilityLabel: "Effacer la recherche du départ",
                    onClear: viewModel.clearDepartureSearch,
                    onSubmit: viewModel.retryDepartureSearch,
                )
                .onChange(of: viewModel.departureQuery) { _, newValue in
                    viewModel.updateDepartureQuery(newValue)
                }
                .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 10, trailing: 16))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)

                if viewModel.departureQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    shortcuts

                    if viewModel.showsRecentDepartureSearches {
                        RecentSearchesSection(
                            searches: viewModel.recentSearches,
                            accessibilityHint: "Sélectionne ce point de départ",
                            onSelect: { recent in
                                select(.manual(recent.searchResult))
                            },
                            onRemove: { recent in
                                viewModel.removeRecentSearch(id: recent.id)
                            },
                            onClear: viewModel.clearRecentSearches,
                        )
                    }
                } else {
                    Section {
                        SearchResultsSection(
                            state: viewModel.departureLoadState,
                            results: viewModel.departureResults,
                            onRetry: viewModel.retryDepartureSearch,
                            onSelect: { result in
                                select(.manual(result))
                            },
                            accessibilityHint: "Sélectionne ce point de départ",
                        )
                    }
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                    .listRowBackground(Color.clear)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Départ")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            viewModel.clearDepartureSearch()
        }
    }

    @ViewBuilder
    private var shortcuts: some View {
        Section {
            shortcutRow(
                title: "Ma position",
                subtitle: "Position actuelle",
                systemImage: "location.fill",
                isSelected: selection == .currentLocation,
                action: { select(.currentLocation) },
            )
        }

        if !savedPlaces.isEmpty || !savedDestinations.isEmpty {
            SavedPlacesBar(
                places: savedPlaces,
                destinations: savedDestinations,
                selectionAccessibilityHint: "Sélectionne ce point de départ",
                isSelectedPlace: { selection == .saved($0) },
                isSelectedDestination: { selection == .savedDestination($0) },
                onSelectPlace: { select(.saved($0)) },
                onSelectDestination: { select(.savedDestination($0)) }
            )
            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 4, trailing: 0))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
        }
    }

    private func shortcutRow(
        title: String,
        subtitle: String?,
        systemImage: String,
        isSelected: Bool,
        action: @escaping () -> Void,
    ) -> some View {
        Button(action: action) {
            SettingsRow(
                title: title,
                systemImage: systemImage,
                subtitle: subtitle,
            )
        }
        .buttonStyle(.plain)
        .accessibilityValue(isSelected ? "Sélectionné" : "Non sélectionné")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func select(_ departure: SearchDepartureSelection) {
        onSelect(departure)
        dismiss()
    }
}

#Preview {
    let locationModel = LocationModel(adapter: InMemoryLocationAdapter())
    SearchDeparturePickerView(
        viewModel: SearchViewModel(
            repository: InMemorySearchRepository.preview,
            journeyRepository: InMemoryJourneyRepository(result: .mapPreview),
            locationModel: locationModel
        ),
        selection: .currentLocation,
        onSelect: { _ in }
    )
}
