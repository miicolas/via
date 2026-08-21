import SwiftUI

struct SearchResultsSection: View {
    let state: SearchLoadState
    let results: [SearchResult]
    let onRetry: () -> Void
    let onSelect: (SearchResult) -> Void

    init(
        state: SearchLoadState,
        results: [SearchResult],
        onRetry: @escaping () -> Void,
        onSelect: @escaping (SearchResult) -> Void
    ) {
        self.state = state
        self.results = results
        self.onRetry = onRetry
        self.onSelect = onSelect
    }

    var body: some View {
        SkeletonGate(isLoading: state == .loading) {
            SkeletonList(
                count: 4,
                label: "Recherche…",
                row: .searchResult,
                separator: .divider(leadingInset: 60)
            )
        } content: {
            loadedContent
        }
    }

    @ViewBuilder
    private var loadedContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            switch state {
            case .idle, .loading:
                EmptyView()

            case .loaded:
                ForEach(results) { result in
                    SearchResultRow(result: result) {
                        onSelect(result)
                    }

                    if result.id != results.last?.id {
                        Divider()
                            .padding(.leading, 60)
                    }
                }

            case .empty:
                EmptyStateView(.noResults())

            case .failed:
                EmptyStateView(.offline(title: "Recherche indisponible")) {
                    RetryButton(action: onRetry)
                        .primaryAction()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    SearchResultsSection(
        state: .loaded,
        results: [.previewStation, .previewAddress],
        onRetry: {},
        onSelect: { _ in }
    )
    .padding()
}
