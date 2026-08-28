import SwiftUI

struct LinesListView: View {
  var summary: LineNetworkSummary
  var fetchedAt: Date?
  var favoriteLines: [LineStatus]
  var sections: [LineStatusSection]
  var extraSearchResults: [LineStatus]
  var upcomingByDay: [UpcomingClosureDay]
  var onSelectLine: (LineStatus) -> Void
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
            lineButton(status)
          }
        }
      }

      if isSearching, !extraSearchResults.isEmpty {
        Section("Autres lignes") {
          ForEach(extraSearchResults) { status in
            lineButton(status)
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

  private func lineButton(_ status: LineStatus) -> some View {
    Button {
      onSelectLine(status)
    } label: {
      LineStatusCard(status: status)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .buttonStyle(.plain)
    .linesCardRow()
  }
}
