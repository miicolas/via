import SwiftUI

struct LinesErrorView: View {
  var onRefresh: () async -> Void

  var body: some View {
    LinesStateScreen {
      EmptyStateView(
        .offline(
          title: "Lignes indisponibles",
          message: "Impossible de charger l’état du réseau. Réessayez."
        )
      ) {
        RetryButton { Task { await onRefresh() } }
          .primaryAction()
      }
    }
  }
}
