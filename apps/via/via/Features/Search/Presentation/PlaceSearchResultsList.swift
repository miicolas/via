import SwiftUI

/// Shared renderer for a `PlaceSearchState`: result rows, loading skeletons,
/// degraded-address banner, empty and failure states. Callers supply only
/// their idle content.
struct PlaceSearchResultsList<IdleContent: View>: View {
    let search: PlaceSearchState
    let onSelect: (SearchResult) -> Void
    let onRetry: () -> Void
    @ViewBuilder let idleContent: () -> IdleContent

    var body: some View {
        if let response = search.visibleResponse {
            if response.addressSource == .unavailable {
                degradedSearchMessage
            }
            ForEach(response.results) { result in
                Button { onSelect(result) } label: {
                    SearchResultRow(result: result)
                }
                .buttonStyle(.plain)
                Divider()
            }
            if search.isLoading {
                SearchLoadingSkeleton(rowCount: 2)
            }
        } else if search.isLoading {
            SearchLoadingSkeleton()
        } else if case .empty(let source) = search {
            ContentUnavailableView(
                "Aucun résultat",
                systemImage: "mappin.slash",
                description: Text(
                    source == .unavailable
                        ? "Les adresses sont indisponibles. Essaie le nom d’une station."
                        : "Essaie une autre station ou une autre adresse."
                )
            )
            .padding(.top, 24)
        } else if case .idle = search {
            idleContent()
        }

        if case .failed = search {
            failedMessage
        }
    }

    private var degradedSearchMessage: some View {
        Label(
            "Les adresses sont momentanément indisponibles. Les stations restent affichées.",
            systemImage: "exclamationmark.triangle.fill"
        )
        .font(.footnote)
        .foregroundStyle(.orange)
        .padding(.vertical, 12)
    }

    private var failedMessage: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "wifi.exclamationmark")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 6) {
                Text("La recherche n’a pas pu être actualisée.")
                    .font(.subheadline.weight(.semibold))
                Button("Réessayer", systemImage: "arrow.clockwise", action: onRetry)
                    .font(.subheadline)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 14)
    }
}
