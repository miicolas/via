import Foundation
import Observation

@MainActor
@Observable
final class LinesViewModel {
  private(set) var board: Loadable<LineStatusBoard> = .idle {
    didSet { rebuildDerivedState() }
  }
  /// Lines the backend matched for the current query — how bus lines,
  /// absent from the permanent rail catalogue, enter the tab.
  private(set) var remoteMatches: [LineStatus] = [] {
    didSet { rebuildDerivedState() }
  }
  private(set) var requestedRouteID: RouteID?
  private(set) var requestedRoute: LineStatus?
  private(set) var favoriteRouteIDs: [RouteID]
  var searchText: String = "" {
    didSet { rebuildDerivedState() }
  }
  var filter = LineStatusFilter() {
    didSet { rebuildDerivedState() }
  }

  /// The non-favorite catalogue, one section per mode in display order.
  /// Within each mode, service interruptions lead so they cannot disappear
  /// below healthy lines during a quick scan.
  ///
  /// Derived state is stored rather than computed: the tab's `body` is
  /// re-evaluated on every frame of a sheet drag, and re-grouping and
  /// re-sorting the whole board there would also hand each child view a fresh
  /// array it can never compare equal to.
  private(set) var sections: [LineStatusSection] = []
  /// Saved lines are kept outside the catalogue sections so they remain above
  /// mode and disruption filters and cannot be rendered twice.
  private(set) var favoriteLines: [LineStatus] = []
  /// Search results the catalogue does not already show — buses, mostly.
  private(set) var extraSearchResults: [LineStatus] = []
  /// Lines with a planned closure, grouped by the day it starts. A traveller
  /// asking for disruptions only is asking about now, not about next week.
  private(set) var upcomingByDay: [UpcomingClosureDay] = []
  private(set) var summary = LineNetworkSummary(lines: [])

  var isSearching: Bool {
    !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  @ObservationIgnored private let repository: any LineStatusRepository
  @ObservationIgnored private let favoriteStore: LineFavoritesStore
  @ObservationIgnored private var hasStarted = false

  init(
    repository: any LineStatusRepository,
    favoriteStore: LineFavoritesStore = LineFavoritesStore()
  ) {
    self.repository = repository
    self.favoriteStore = favoriteStore
    self.favoriteRouteIDs = favoriteStore.load()
    rebuildDerivedState()
  }

  /// Keeps the statuses fresh while the tab is visible. The view owns the
  /// surrounding task, so leaving the tab cancels the loop automatically.
  func runAutomaticRefresh(every interval: Duration = .seconds(60)) async {
    await loadIfNeeded()

    while !Task.isCancelled {
      do {
        try await Task.sleep(for: interval)
      } catch {
        return
      }

      guard !Task.isCancelled else { return }
      await refresh()
    }
  }

  func loadIfNeeded() async {
    guard !hasStarted else { return }
    hasStarted = true
    await refresh()
  }

  func refresh() async {
    board = .loading(previous: board.value)
    do {
      board = .loaded(try await repository.statuses())
    } catch is CancellationError {
      board = .failed(.transport, previous: board.value)
    } catch {
      board = .failed(error.via, previous: board.value)
    }
  }

  /// Debounced by the view through `.task(id: searchText)`.
  func search(query: String) async {
    let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed.count >= 2 else {
      remoteMatches = []
      return
    }

    do {
      try await Task.sleep(for: .milliseconds(250))
      let response = try await repository.searchLines(query: trimmed)
      guard !Task.isCancelled, searchText == query else { return }
      remoteMatches = response.lines
    } catch {
      guard !Task.isCancelled else { return }
      remoteMatches = []
    }
  }

  /// Keeps construction of line detail state behind the browsing module.
  /// Navigation callers select a route without learning which adapter the
  /// detail screen needs.
  func detailViewModel(for route: RouteBadge) -> LineDetailViewModel {
    LineDetailViewModel(repository: repository, lineID: route.id)
  }

  var hasFavoriteLines: Bool {
    !favoriteLines.isEmpty
  }

  func isFavorite(_ routeID: RouteID) -> Bool {
    favoriteRouteIDs.contains(routeID)
  }

  @discardableResult
  func toggleFavorite(route: RouteBadge) -> Bool {
    let wasFavorite = isFavorite(route.id)
    if wasFavorite {
      favoriteRouteIDs.removeAll { $0 == route.id }
    } else {
      favoriteRouteIDs.insert(route.id, at: 0)
    }
    favoriteStore.save(favoriteRouteIDs)
    rebuildDerivedState()
    return !wasFavorite
  }

  func requestRoute(_ routeID: RouteID) {
    requestedRouteID = routeID
  }

  func requestNaturalLineStatus(_ navigation: NaturalLineStatusNavigation) {
    searchText = navigation.searchText
    filter = LineStatusFilter(
      mode: navigation.mode,
      disruptionsOnly: navigation.disruptionsOnly
    )
    requestedRoute = navigation.route
  }

  func consumeRequestedRoute() {
    requestedRouteID = nil
    requestedRoute = nil
  }

  private func rebuildDerivedState() {
    let catalogue = board.value?.lines ?? []
    let favoriteIDs = Set(favoriteRouteIDs)

    // The catalogue is the authoritative status source. Search results are a
    // fallback for routes (mostly buses) that are not in that catalogue.
    // Favorites intentionally skip both the search query and the catalogue
    // filter: the strip is the traveller's always-available shortcut.
    favoriteLines = favoriteRouteIDs.compactMap { routeID in
      catalogue.first(where: { $0.id == routeID })
        ?? remoteMatches.first(where: { $0.id == routeID })
    }

    let visible = catalogue.filter {
      !favoriteIDs.contains($0.id)
        && $0.matchesSearch(searchText)
        && filter.matches($0)
    }
    let byMode = Dictionary(grouping: visible, by: \.route.mode)
    sections = TransitMode.allCases.compactMap { mode in
      guard let lines = byMode[mode], !lines.isEmpty else { return nil }
      return LineStatusSection(mode: mode, lines: lines.sortedForDisplay)
    }

    let knownIDs = Set(catalogue.map(\.id))
    extraSearchResults =
      remoteMatches
      .filter {
        !knownIDs.contains($0.id)
          && !favoriteIDs.contains($0.id)
          && filter.matches($0)
      }
      .sortedForDisplay

    // The summary describes the filter result, including favorite lines even
    // though those lines are rendered in the quick-access strip above.
    summary = LineNetworkSummary(
      lines: catalogue.filter { $0.matchesSearch(searchText) && filter.matches($0) }
    )

    upcomingByDay = filter.disruptionsOnly ? [] : Self.groupedByDay(catalogue, mode: filter.mode)
  }

  private static func groupedByDay(
    _ lines: [LineStatus],
    mode: TransitMode?
  ) -> [UpcomingClosureDay] {
    let calendar = Calendar.current
    let upcoming = lines.compactMap { status -> (Date, LineStatus)? in
      guard let beginsAt = status.upcoming?.beginsAt,
        mode == nil || status.route.mode == mode
      else { return nil }
      return (calendar.startOfDay(for: beginsAt), status)
    }

    return Dictionary(grouping: upcoming, by: \.0)
      .map { day, entries in
        UpcomingClosureDay(
          day: day,
          lines: entries.map(\.1).sorted {
            ($0.upcoming?.beginsAt ?? .distantFuture) < ($1.upcoming?.beginsAt ?? .distantFuture)
          }
        )
      }
      .sorted { $0.day < $1.day }
  }
}

extension Collection where Element == LineStatus {
  fileprivate var sortedForDisplay: [LineStatus] {
    sorted { lhs, rhs in
      if lhs.condition.displayPriority != rhs.condition.displayPriority {
        return lhs.condition.displayPriority < rhs.condition.displayPriority
      }

      return lhs.route.shortName.localizedStandardCompare(rhs.route.shortName) == .orderedAscending
    }
  }
}
