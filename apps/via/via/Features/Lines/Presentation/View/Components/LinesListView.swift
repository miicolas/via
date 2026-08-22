import SwiftUI

struct LinesListView: View {
  var summary: LineNetworkSummary
  var fetchedAt: Date?
  var sections: [LineStatusSection]
  var extraSearchResults: [LineStatus]
  var upcomingByDay: [UpcomingClosureDay]
  var isSearching: Bool
  var isRefreshing: Bool
  var showsUnavailableBanner: Bool
  var onRefresh: () async -> Void

  var body: some View {
    List {
      if !isSearching {
        LinesNetworkSummaryView(
          summary: summary,
          fetchedAt: fetchedAt,
          isRefreshing: isRefreshing
        )
        .linesCardRow(top: 8, bottom: 14)
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
    .refreshable { await onRefresh() }
  }

  private func lineLink(_ status: LineStatus) -> some View {
    NavigationLink(value: status) {
      LineStatusCard(status: status)
    }
    .linesCardRow()
  }
}
