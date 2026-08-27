import SwiftUI

struct StationDeparturesSection: View {
  var routes: [RouteBadge]
  var departures: [StationDeparture]
  var source: DepartureBoard.Source
  var fetchedAt: Date?
  var loadingState: SelectedStationLoadingState
  var onRetry: () -> Void
  var title = "Prochains passages"
  var onSelectRoute: ((RouteBadge) -> Void)? = nil

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      VStack(alignment: .leading, spacing: 3) {
        Text(title)
          .font(.headline)

        DepartureFreshnessView(source: source, fetchedAt: fetchedAt)

        if onSelectRoute != nil && routes.count > 1 {
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
        if let onSelectRoute {
          Button {
            onSelectRoute(route)
          } label: {
            HStack(spacing: 8) {
              routeRows(for: route)

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
        } else {
          routeRows(for: route)
        }

        if index < routes.count - 1 {
          Divider()
            .padding(.leading, 50)
        }
      }
    }
  }

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
