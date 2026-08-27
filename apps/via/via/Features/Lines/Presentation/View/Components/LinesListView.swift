import SwiftUI

struct LinesListView: View {
  var summary: LineNetworkSummary
  var fetchedAt: Date?
  var favoriteLines: [LineStatus]
  var sections: [LineStatusSection]
  var extraSearchResults: [LineStatus]
  var upcomingByDay: [UpcomingClosureDay]
  var isFavorite: (RouteID) -> Bool
  var onToggleFavorite: (RouteBadge) -> Void
  var isSearching: Bool
  var isRefreshing: Bool
  var showsUnavailableBanner: Bool
  var onRefresh: () async -> Void

  var body: some View {
    List {
      if !favoriteLines.isEmpty {
        FavoriteLinesSection(lines: favoriteLines)
      }

      if !isSearching {
        LinesNetworkSummaryView(
          summary: summary,
          fetchedAt: fetchedAt,
          isRefreshing: isRefreshing
        )
        .linesCardRow(top: 4, bottom: 4)
      }

      if showsUnavailableBanner {
        LinesUnavailableBanner()
          .linesCardRow(top: 0, bottom: 12)
      }

      ForEach(sections) { section in
        Section(section.mode.displayName) {
          ForEach(section.lines) { status in
            lineLink(status)
          }
        }
      }

      if isSearching, !extraSearchResults.isEmpty {
        Section("Autres lignes") {
          ForEach(extraSearchResults) { status in
            lineLink(status)
          }
        }
      }

      if !isSearching {
        UpcomingClosuresSection(days: upcomingByDay)
      }
    }
    .listStyle(.plain)
    .scrollContentBackground(.hidden)
    .hapticRefreshable { await onRefresh() }
  }

  private func lineLink(_ status: LineStatus) -> some View {
    HStack(spacing: 8) {
      NavigationLink(value: status) {
        LineStatusCard(status: status)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
      .buttonStyle(.plain)

      FavoriteLineButton(
        route: status.route,
        isFavorite: isFavorite(status.route.id),
        action: { onToggleFavorite(status.route) }
      )
    }
    .linesCardRow()
  }
}
