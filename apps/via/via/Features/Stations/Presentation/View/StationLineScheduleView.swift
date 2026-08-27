import SwiftUI

/// The deep timetable sheet for one line at a selected station.
struct StationLineScheduleView: View {
  let selection: SelectedStationModel
  let route: RouteBadge
  let isLargeScreen: Bool

  @Environment(\.dismiss) private var dismiss
  @State private var detailDetent: PresentationDetent = .large

  var body: some View {
    NavigationStack {
      if let station = selection.overview {
        ScrollView {
          VStack(alignment: .leading, spacing: 24) {
            lineHeader(stationName: station.name)

            StationDeparturesSection(
              routes: [route],
              departures: selection.lineScheduleDepartures,
              source: selection.lineScheduleSource,
              fetchedAt: selection.lineScheduleFetchedAt,
              loadingState: selection.lineScheduleLoadingState,
              onRetry: selection.retryLineSchedule,
              title: "Passages restants aujourd’hui"
            )
          }
          .padding(.horizontal, 20)
          .padding(.top, 16)
          .padding(.bottom, 32)
          .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("Ligne \(route.shortName)")
        .toolbarTitleDisplayMode(.inlineLarge)
        .toolbar {
          ToolbarItem(placement: .topBarTrailing) {
            Button(role: .close) {
              dismiss()
            }
          }
        }
      } else {
        EmptyStateView(
          .unavailable(
            title: "Arrêt indisponible",
            message: "Le détail de cette ligne n’est plus disponible."
          )
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
    }
    .task {
      guard selection.lineScheduleRoute?.id != route.id else { return }
      selection.selectLine(route)
    }
    .detailSheetPresentation(isLargeScreen: isLargeScreen, selection: $detailDetent)
  }

  private func lineHeader(stationName: String) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 12) {
        LineBadgeView(route: route, size: 38)

        VStack(alignment: .leading, spacing: 2) {
          Text(stationName)
            .font(.title3.weight(.semibold))
            .foregroundStyle(.primary)

          Text("Horaires de la ligne \(route.shortName)")
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
      }

      Label(
        "Prévision des passages jusqu’à la fin du service",
        systemImage: "calendar"
      )
      .font(.callout)
      .foregroundStyle(.secondary)
    }
  }
}
