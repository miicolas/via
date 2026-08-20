import SwiftUI

struct SearchResultsSection: View {
    let state: SearchLoadState
    let results: [SearchResult]
    let onRetry: () -> Void
    let onSelect: (SearchResult) -> Void

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
                SearchEmptyStateView(
                    message: "Essayez un autre nom de station ou d’adresse."
                )

            case .failed:
                SearchEmptyStateView(
                    title: "Recherche indisponible",
                    message: "Vérifiez votre connexion puis réessayez.",
                    actionTitle: "Réessayer",
                    action: onRetry
                )
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
