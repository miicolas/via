import SwiftUI

/// Picks the address behind a saved place, without leaving Settings. It is
/// the departure picker stripped of everything a journey needs: one field,
/// one list of results, and the result travels straight to the editor.
struct SavedDestinationSearchView: View {
    let viewModel: SearchViewModel
    let title: String
    let onSelect: (SearchResult) -> Void

    @Environment(\.dismiss) private var dismiss

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

                Section {
                    SearchResultsSection(
                        state: viewModel.departureLoadState,
                        results: viewModel.departureResults,
                        onRetry: viewModel.retryDepartureSearch,
                        onSelect: select,
                        accessibilityHint: "Enregistre ce lieu dans vos favoris",
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
