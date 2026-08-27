import SwiftUI

/// The compact board on the station sheet: one line, one row, the next passage.
///
/// The board answers a single question — what do I take now — so a line gets one
/// row whatever the number of directions behind it. Everything else about that
/// line, including its other direction and the rest of its day, lives one tap
/// away in `StationLineScheduleView`.
struct StationDeparturesSection: View {
  var routes: [RouteBadge]
  var departures: [StationDeparture]
  var source: DepartureBoard.Source
  var fetchedAt: Date?
  var loadingState: SelectedStationLoadingState
  var onRetry: () -> Void
  var onSelectRoute: (RouteBadge) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      VStack(alignment: .leading, spacing: 3) {
        Text("Prochains passages")
          .font(.headline)

        DepartureFreshnessView(source: source, fetchedAt: fetchedAt)

        if !routes.isEmpty {
          Text("Touchez une ligne pour voir tous ses horaires.")
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
      }

      if routes.isEmpty {
        EmptyStateView(
          EmptyState(
            title: "Aucune ligne",
            message: "Aucune desserte n’est renseignée pour cette station."
          )
        )
      } else if loadingState == .loading && departures.isEmpty {
        // The desserte is already known, so the first load draws one placeholder
        // row per line instead of a spinner — the board keeps its geometry and
        // the rows settle in place.
        SkeletonGate(isLoading: true) {
          SkeletonList(
            count: routes.count,
            label: "Chargement des prochains passages…",
            row: .departure,
            separator: .divider(leadingInset: 50)
          )
        }
      } else {
        departureRows

        switch loadingState {
        case .loading:
          LoadingStatus(label: "Actualisation…")
            .frame(maxWidth: .infinity)
            .padding(.top, 4)
        case .failed:
          StationRefreshStatusView(
            message: "Impossible d’actualiser les prochains passages.",
            onRetry: onRetry
          )
          .padding(.top, 4)
        case .idle, .loaded:
          EmptyView()
        }
      }
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.regularMaterial, in: .rect(cornerRadius: 20))
  }

  private var departureRows: some View {
    VStack(alignment: .leading, spacing: 0) {
      ForEach(routes.enumerated(), id: \.element.id) { index, route in
        Button {
          onSelectRoute(route)
        } label: {
          HStack(spacing: 8) {
            DepartureLineRow(
              route: route,
              departure: StationOverviewBuilder.nextDeparture(for: route, in: departures),
              source: source
            )

            Image(systemName: "chevron.right")
              .font(.caption.weight(.semibold))
              .foregroundStyle(.tertiary)
              .accessibilityHidden(true)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Horaires de \(route.mode.displayName) ligne \(route.shortName)")
        .accessibilityHint("Affiche tous les horaires de la ligne jusqu’à la fin du service.")

        if index < routes.count - 1 {
          Divider()
            .padding(.leading, 50)
        }
      }
    }
  }
}
