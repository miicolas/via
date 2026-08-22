import SwiftUI

struct LinesNoResultsView: View {
  var searchText: String
  var isSearching: Bool
  var filtersAreActive: Bool
  var onRefresh: () async -> Void
  var onResetFilters: () -> Void

  var body: some View {
    LinesStateScreen {
      EmptyStateView(emptyState) {
        if isSearching {
          EmptyStateHint(
            Text(
              "Modifiez \(Image(systemName: "magnifyingglass.circle.fill")) Recherche ci-dessus pour trouver une ligne"
            ),
            label: "Modifiez Recherche ci-dessus pour trouver une ligne"
          )
        }

        if filtersAreActive {
          Button("Réinitialiser les filtres", systemImage: "arrow.counterclockwise") {
            onResetFilters()
          }
          .primaryAction()
        } else if !isSearching {
          RetryButton { Task { await onRefresh() } }
            .primaryAction()
        }
      }
    }
  }

  private var emptyState: EmptyState {
    if isSearching {
      return .noResults(
        query: searchText,
        message: "Essayez un autre nom de ligne ou de mode."
      )
    }

    if filtersAreActive {
      return .filtered(
        title: "Aucune ligne avec ces filtres",
        message: "Affichez davantage de modes ou incluez les lignes sans perturbation."
      )
    }

    return .unavailable(
      title: "Aucune ligne disponible",
      message: "Le catalogue du réseau est vide pour le moment."
    )
  }
}
