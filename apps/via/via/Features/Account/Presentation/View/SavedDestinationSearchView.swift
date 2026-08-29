import SwiftUI

/// Picks the address behind a saved place, without leaving Settings. It is
/// the departure picker stripped of everything a journey needs: one field,
/// one list of results, and the result travels straight to the editor.
struct SavedDestinationSearchView: View {
    let viewModel: SearchViewModel
    let title: String
    let accessibilityHint: String
    let onSelect: (SearchResult) -> Void

    @Environment(\.dismiss) private var dismiss

    init(
        viewModel: SearchViewModel,
        title: String,
        accessibilityHint: String = "Enregistre ce lieu dans vos favoris",
        onSelect: @escaping (SearchResult) -> Void,
    ) {
        self.viewModel = viewModel
        self.title = title
        self.accessibilityHint = accessibilityHint
        self.onSelect = onSelect
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        NavigationStack {
            List {
                SearchDestinationField(
                    text: $viewModel.departureQuery,
                    prompt: "Station ou adresse",
                    accessibilityLabel: "Adresse de \(title)",
                    clearAccessibilityLabel: "Effacer la recherche",
                    onClear: viewModel.clearDepartureSearch,
                    onSubmit: viewModel.retryDepartureSearch,
                )
                .onChange(of: viewModel.departureQuery) { _, newValue in
                    viewModel.updateDepartureQuery(newValue)
                }
                .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 10, trailing: 16))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)

                if showsSavedPlacesBar(viewModel) {
                    SavedPlacesBar(
                        places: viewModel.savedPlaces,
                        destinations: viewModel.savedDestinations,
                        selectionAccessibilityHint: accessibilityHint,
                        onSelectPlace: { select($0.searchResult) },
                        onSelectDestination: { select($0.searchResult) }
                    )
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 4, trailing: 0))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }

                Section {
                    SearchResultsSection(
                        state: viewModel.departureLoadState,
                        results: viewModel.departureResults,
                        onRetry: viewModel.retryDepartureSearch,
                        onSelect: select,
                        accessibilityHint: accessibilityHint,
                    )
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                .listRowBackground(Color.clear)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(title)
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .close) {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            viewModel.clearDepartureSearch()
        }
    }

    private func select(_ result: SearchResult) {
        onSelect(result)
        dismiss()
    }

    private func showsSavedPlacesBar(_ viewModel: SearchViewModel) -> Bool {
        viewModel.departureQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && viewModel.departureLoadState == .idle
            && (!viewModel.savedPlaces.isEmpty || !viewModel.savedDestinations.isEmpty)
    }
}

#Preview {
    let locationModel = LocationModel(adapter: InMemoryLocationAdapter())

    SavedDestinationSearchView(
        viewModel: SearchViewModel(
            repository: InMemorySearchRepository.preview,
            journeyRepository: InMemoryJourneyRepository(result: .mapPreview),
            locationModel: locationModel
        ),
        title: "Maison",
        onSelect: { _ in }
    )
}
