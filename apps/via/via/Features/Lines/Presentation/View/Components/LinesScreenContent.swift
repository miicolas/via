import SwiftUI

struct LinesScreenContent: View {
  var viewModel: LinesViewModel

  var body: some View {
    switch viewModel.board {
    case .idle, .loading(previous: nil):
      SkeletonGate(isLoading: true) { LinesLoadingView() }
    case .failed(_, previous: nil):
      LinesErrorView(onRefresh: viewModel.refresh)
    case .loading(previous: .some(let board)):
      settledContent(board: board, isRefreshing: true, isStale: false)
    case .loaded(let board):
      settledContent(board: board, isRefreshing: false, isStale: false)
    case .failed(_, previous: .some(let board)):
      settledContent(board: board, isRefreshing: false, isStale: true)
    }
  }

  @ViewBuilder
  private func settledContent(
    board: LineStatusBoard,
    isRefreshing: Bool,
    isStale: Bool
  ) -> some View {
    if hasVisibleLines {
      LinesListView(
        summary: viewModel.summary,
        fetchedAt: board.fetchedAt,
        favoriteLines: viewModel.favoriteLines,
        sections: viewModel.sections,
        extraSearchResults: viewModel.extraSearchResults,
        upcomingByDay: viewModel.upcomingByDay,
        isSearching: viewModel.isSearching,
        isRefreshing: isRefreshing,
        showsUnavailableBanner: isStale || board.source == .unavailable,
        onRefresh: viewModel.refresh
      )
    } else {
      LinesNoResultsView(
        searchText: viewModel.searchText,
        isSearching: viewModel.isSearching,
        filtersAreActive: viewModel.filter.isActive,
        onRefresh: viewModel.refresh,
        onResetFilters: { viewModel.filter.reset() }
      )
    }
  }

  private var hasVisibleLines: Bool {
    viewModel.hasFavoriteLines
      || !viewModel.sections.isEmpty
      || (viewModel.isSearching && !viewModel.extraSearchResults.isEmpty)
  }
}
