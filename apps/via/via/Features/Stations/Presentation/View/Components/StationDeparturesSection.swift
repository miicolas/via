import SwiftUI

/// The compact board on the station sheet: one row per direction, each showing
/// that direction's next passage.
///
/// A line's two directions go opposite ways, so they are two answers, not one —
/// but only their next passage belongs here. The rest of the line's day lives
/// one tap away, in `StationLineScheduleView`.
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
            // Vertically: a `ForEach` dropped straight into the `HStack` laid the
            // directions of a line out side by side, and the second one left the
            // screen.
            VStack(alignment: .leading, spacing: 0) {
              routeRows(for: route)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.right")
              .font(.caption.weight(.semibold))
              .foregroundStyle(.tertiary)
              .accessibilityHidden(true)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        // Combined, but not relabelled: a custom label would replace the rows'
        // own text, and VoiceOver would hear the name of a line whose passages
        // it can no longer read.
        .accessibilityElement(children: .combine)
        .accessibilityHint("Affiche tous les horaires de la ligne jusqu’à la fin du service.")

        if index < routes.count - 1 {
          Divider()
            .padding(.leading, 50)
        }
      }
    }
  }

  /// One row per direction, on that direction's next passage, in the board's own
  /// order — sorting the two directions by time would have them swap places
  /// under the finger every time one overtakes the other. A line the board has no
  /// passage for still gets its row: "aucun passage à venir" is an answer, a
  /// missing line is not.
  @ViewBuilder
  private func routeRows(for route: RouteBadge) -> some View {
    let routeDepartures = departures.filter { $0.route.id == route.id }

    if routeDepartures.isEmpty {
      DepartureLineRow(route: route, departure: nil, source: source)
    } else {
      ForEach(routeDepartures) { departure in
        DepartureLineRow(route: route, departure: departure, source: source)
      }
    }
  }
}
