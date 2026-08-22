import SwiftUI

struct SearchResultsSection: View {
    let state: SearchLoadState
    let results: [SearchResult]
    let onRetry: () -> Void
    let onSelect: (SearchResult) -> Void
    let accessibilityHint: String

    init(
        state: SearchLoadState,
        results: [SearchResult],
        onRetry: @escaping () -> Void,
        onSelect: @escaping (SearchResult) -> Void,
        accessibilityHint: String = "Sélectionne cette destination",
    ) {
        self.state = state
        self.results = results
        self.onRetry = onRetry
        self.onSelect = onSelect
        self.accessibilityHint = accessibilityHint
    }

    var body: some View {
        switch state {
        case .idle:
            EmptyView()

        case .loading:
            SkeletonGate(isLoading: true) {
                SkeletonList(
                    count: 4,
                    label: "Recherche…",
                    row: .searchResult,
                    separator: .divider(leadingInset: 46)
                )
            }

        case .loaded:
            ForEach(results) { result in
                SearchResultRow(result: result, accessibilityHint: accessibilityHint) {
                    onSelect(result)
                }
            }

            case .empty:
                EmptyStateView(.noResults()) {
                    EmptyStateHint(
                        Text("Modifiez \(Image(systemName: "magnifyingglass.circle.fill")) Recherche ci-dessus pour trouver une station"),
                        label: "Modifiez Recherche ci-dessus pour trouver une station",
                    )
                }

        case .failed:
            EmptyStateView(.offline(title: "Recherche indisponible")) {
                RetryButton(action: onRetry)
                    .primaryAction()
            }
        }
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
