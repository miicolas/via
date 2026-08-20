import SwiftUI

struct SearchManualDepartureView: View {
    let searchPlaces: @MainActor (String) async throws -> SearchResponse
    let onSelect: (SearchResult) -> Void
    let filters: SearchFilters
    let onSetRequiresAccessibleStations: @MainActor (Bool) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var results: [SearchResult] = []
    @State private var loadState: SearchLoadState = .idle
    @State private var searchRequestID = 0
    @State private var isAccessibilityInfoPresented = false
    @State private var accessibilitySource = SearchResponse.AccessibilitySource(
        status: .unavailable,
        sourceUpdatedAt: nil,
        importedAt: nil
    )

    init(
        searchPlaces: @escaping @MainActor (String) async throws -> SearchResponse,
        onSelect: @escaping (SearchResult) -> Void,
        filters: SearchFilters = .init(),
        onSetRequiresAccessibleStations: @escaping @MainActor (Bool) -> Void = { _ in }
    ) {
        self.searchPlaces = searchPlaces
        self.onSelect = onSelect
        self.filters = filters
        self.onSetRequiresAccessibleStations = onSetRequiresAccessibleStations
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    SearchDestinationField(
                        text: $query,
                        onClear: { query = "" },
                        onSubmit: { searchRequestID += 1 }
                    )

                    SearchResultsSection(
                        state: loadState,
                        results: results,
                        onRetry: { searchRequestID += 1 },
                        onSelect: { result in
                            onSelect(result)
                            dismiss()
                        }
                    )
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
            }
            .navigationTitle("Départ manuel")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    SearchFiltersMenu(
                        filters: filters,
                        onSetRequiresAccessibleStations: onSetRequiresAccessibleStations,
                        onShowAccessibilityInfo: { isAccessibilityInfoPresented = true }
                    )
                }
            }
        }
        .sheet(isPresented: $isAccessibilityInfoPresented) {
            SearchAccessibilityInfoView(source: accessibilitySource)
        }
        .task(id: "\(query)-\(searchRequestID)") {
            await search()
        }
    }

    private func search() async {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.count >= 2 else {
            results = []
            loadState = .idle
            return
        }

        do {
            try await Task.sleep(for: .milliseconds(250))
        } catch {
            return
        }

        guard !Task.isCancelled else { return }
        loadState = .loading

        do {
            let response = try await searchPlaces(normalized)
            guard !Task.isCancelled else { return }
            results = response.results
            accessibilitySource = response.accessibilitySource
            loadState = results.isEmpty ? .empty : .loaded
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled else { return }
            loadState = .failed(error.via)
        }
    }
}

#Preview {
    let locationModel = LocationModel(adapter: InMemoryLocationAdapter())
    SearchManualDepartureView(
        searchPlaces: SearchViewModel(
            repository: InMemorySearchRepository.preview,
            journeyRepository: InMemoryJourneyRepository(result: .mapPreview),
            locationModel: locationModel
        )
            .searchPlaces
    ) { _ in }
}
