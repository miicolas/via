import XCTest

@testable import Via

private struct StubLineStatusRepository: LineStatusRepository {
  let board: LineStatusBoard
  let searchBoard: LineStatusBoard

  func statuses() async throws -> LineStatusBoard { board }
  func searchLines(query: String) async throws -> LineStatusBoard { searchBoard }
  func detail(lineID: RouteID) async throws -> LineDetail { throw ViaError.unavailable }
}

final class LinesViewModelTests: XCTestCase {
  private func status(
    _ id: String,
    _ shortName: String,
    _ mode: TransitMode,
    condition: LineCondition = .normal,
    upcoming: UpcomingClosure? = nil
  ) -> LineStatus {
    LineStatus(
      route: RouteBadge(
        id: RouteID(rawValue: id),
        shortName: shortName,
        mode: mode,
        colorHex: "#FFCD00",
        textColorHex: "#000000"
      ),
      condition: condition,
      summary: condition == .normal ? nil : "Perturbation en cours",
      activeCount: condition == .normal ? 0 : 1,
      upcoming: upcoming
    )
  }

  private func board(_ lines: [LineStatus]) -> LineStatusBoard {
    LineStatusBoard(source: .live, fetchedAt: .now, lines: lines)
  }

  @MainActor
  func testSectionsGroupByModeInDisplayOrder() async {
    let repository = PreviewLineStatusRepository(
      board: board([
        status("t3a", "T3a", .tram),
        status("m1", "1", .metro),
        status("rer-a", "A", .rer),
        status("m4", "4", .metro, condition: .disrupted),
      ])
    )
    let viewModel = LinesViewModel(repository: repository)
    await viewModel.refresh()

    XCTAssertEqual(viewModel.sections.map(\.mode), [.metro, .rer, .tram])
    XCTAssertEqual(viewModel.sections[0].lines.map(\.route.shortName), ["4", "1"])
  }

  @MainActor
  func testSectionsApplyModeAndDisruptionFilters() async {
    let repository = PreviewLineStatusRepository(
      board: board([
        status("m1", "1", .metro),
        status("m4", "4", .metro, condition: .disrupted),
        status("rer-a", "A", .rer, condition: .attention),
      ])
    )
    let viewModel = LinesViewModel(repository: repository)
    await viewModel.refresh()

    viewModel.filter = LineStatusFilter(mode: .metro, disruptionsOnly: true)

    XCTAssertEqual(viewModel.sections.map(\.mode), [.metro])
    XCTAssertEqual(viewModel.sections.flatMap(\.lines).map(\.route.shortName), ["4"])
    XCTAssertTrue(viewModel.filter.isActive)
  }

  @MainActor
  func testSearchTextNarrowsTheCatalogueWithDiacriticsIgnored() async {
    let repository = PreviewLineStatusRepository(
      board: board([
        status("m1", "1", .metro),
        status("rer-a", "A", .rer),
      ])
    )
    let viewModel = LinesViewModel(repository: repository)
    await viewModel.refresh()

    viewModel.searchText = "metro"
    XCTAssertEqual(viewModel.sections.flatMap(\.lines).map(\.route.shortName), ["1"])

    viewModel.searchText = "rer a"
    XCTAssertEqual(viewModel.sections.flatMap(\.lines).map(\.route.shortName), ["A"])
  }

  @MainActor
  func testExtraSearchResultsExcludeCatalogueLines() async {
    let metro1 = status("m1", "1", .metro)
    let bus38 = status("bus-38", "38", .bus)
    let repository = StubLineStatusRepository(
      board: board([metro1]),
      searchBoard: board([metro1, bus38])
    )
    let viewModel = LinesViewModel(repository: repository)
    await viewModel.refresh()

    viewModel.searchText = "38"
    await viewModel.search(query: "38")

    XCTAssertEqual(viewModel.extraSearchResults.map(\.route.shortName), ["38"])
  }

  @MainActor
  func testUpcomingClosuresGroupByDayInOrder() async {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: .now)
    let tonight = today.addingTimeInterval(22 * 3_600)
    let inThreeDays = calendar.date(byAdding: .day, value: 3, to: tonight)!

    let repository = PreviewLineStatusRepository(
      board: board([
        status(
          "m14", "14", .metro,
          upcoming: UpcomingClosure(beginsAt: inThreeDays, title: "Travaux")
        ),
        status(
          "m1", "1", .metro,
          upcoming: UpcomingClosure(beginsAt: tonight, title: "Fermeture à 22 h")
        ),
        status("rer-a", "A", .rer),
      ])
    )
    let viewModel = LinesViewModel(repository: repository)
    await viewModel.refresh()

    let days = viewModel.upcomingByDay
    XCTAssertEqual(days.count, 2)
    XCTAssertEqual(days[0].day, today)
    XCTAssertEqual(days[0].lines.map(\.route.shortName), ["1"])
    XCTAssertEqual(days[1].lines.map(\.route.shortName), ["14"])
  }

  @MainActor
  func testUpcomingClosuresCanBeFilteredByMode() async {
    let beginsAt = Calendar.current.date(byAdding: .day, value: 1, to: .now)!
    let closure = UpcomingClosure(beginsAt: beginsAt, title: "Travaux")
    let repository = PreviewLineStatusRepository(
      board: board([
        status("m14", "14", .metro, upcoming: closure),
        status("rer-a", "A", .rer, upcoming: closure),
      ])
    )
    let viewModel = LinesViewModel(repository: repository)
    await viewModel.refresh()

    viewModel.filter.mode = .rer
    XCTAssertEqual(viewModel.upcomingByDay.flatMap(\.lines).map(\.route.shortName), ["A"])

    // A traveller asking for disruptions only is asking about now, not about
    // next week: the closures section empties with them.
    viewModel.filter.disruptionsOnly = true
    XCTAssertTrue(viewModel.upcomingByDay.isEmpty)
  }

  func testCutSegmentsCoverTheSectionRegardlessOfDirection() {
    let branch = LineBranch(
      id: "p-1",
      directionId: 0,
      headsign: "Château de Vincennes",
      isCanonical: true,
      stops: [
        LineStop(id: "s1", name: "La Défense"),
        LineStop(id: "s2", name: "Concorde"),
        LineStop(id: "s3", name: "Châtelet"),
        LineStop(id: "s4", name: "Nation"),
      ]
    )
    let disruption = LineDisruption(
      id: "d-1",
      condition: .suspended,
      isActive: true,
      cause: nil,
      title: nil,
      message: nil,
      periods: [],
      impactedSections: [
        LineImpactedSection(
          fromStopID: "s4",
          fromName: "Nation",
          toStopID: "s2",
          toName: "Concorde"
        )
      ],
      updatedAt: nil
    )

    XCTAssertEqual(branch.cutSegmentIndexes(for: [disruption]), [1, 2])
  }

  func testCutSegmentsIgnoreInactiveDisruptionsAndForeignStops() {
    let branch = LineBranch(
      id: "p-1",
      directionId: 0,
      headsign: "Terminus",
      isCanonical: true,
      stops: [LineStop(id: "s1", name: "A"), LineStop(id: "s2", name: "B")]
    )
    let upcoming = LineDisruption(
      id: "d-upcoming",
      condition: .attention,
      isActive: false,
      cause: nil,
      title: nil,
      message: nil,
      periods: [],
      impactedSections: [
        LineImpactedSection(fromStopID: "s1", fromName: "A", toStopID: "s2", toName: "B")
      ],
      updatedAt: nil
    )
    let foreign = LineDisruption(
      id: "d-foreign",
      condition: .suspended,
      isActive: true,
      cause: nil,
      title: nil,
      message: nil,
      periods: [],
      impactedSections: [
        LineImpactedSection(fromStopID: "x1", fromName: "X", toStopID: "x2", toName: "Y")
      ],
      updatedAt: nil
    )

    XCTAssertEqual(branch.cutSegmentIndexes(for: [upcoming, foreign]), [])
  }
}
