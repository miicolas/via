import Foundation
import XCTest

@testable import Via

@MainActor
final class SelectedStationModelTests: XCTestCase {
  func testMapSelectionPublishesPlaceholderThenLoadsDepartures() async {
    let now = Date(timeIntervalSince1970: 2_000_000)
    let route = makeRoute(id: "metro-1", shortName: "1")
    let item = makeItem(id: "station", route: route)
    let board = DepartureBoard(
      source: .realtime,
      generatedAt: now,
      groups: [
        DepartureGroup(
          route: route,
          destination: "La Défense",
          departureItems: [
            DepartureItem(
              id: "first",
              scheduledAt: now.addingTimeInterval(300),
              expectedAt: nil,
              delaySeconds: nil,
              status: .onTime
            ),
            DepartureItem(
              id: "second",
              scheduledAt: now.addingTimeInterval(600),
              expectedAt: nil,
              delaySeconds: nil,
              status: .onTime
            ),
          ]
        )
      ]
    )
    let model = makeModel(
      departures: DelayedSelectedDeparturesRepository(boards: [item.id: board]),
      now: now
    )

    model.select(item)

    XCTAssertEqual(model.overview?.id, item.id)
    XCTAssertEqual(model.loadingState, .loading)
    XCTAssertEqual(model.overview?.departureSource, .unavailable)
    XCTAssertTrue(model.overview?.departures.isEmpty == true)
    XCTAssertEqual(model.overview?.accessibility?.condition, .autonomous)
    XCTAssertEqual(model.overview?.fountains?.status, .available)

    await waitUntil { model.overview?.departureSource == .realtime }

    XCTAssertEqual(model.overview?.departures.first?.destination, "La Défense")
    XCTAssertEqual(model.overview?.departureBoard.map(\.id), ["first", "second"])
    XCTAssertEqual(model.overview?.accessibility?.condition, .autonomous)
    XCTAssertEqual(model.overview?.fountains?.status, .available)
    XCTAssertEqual(model.loadingState, .loaded)
  }

  func testSelectingLineLoadsItsCompleteBoardInChronologicalOrder() async {
    let now = Date(timeIntervalSince1970: 2_000_000)
    let line = makeRoute(id: "metro-1", shortName: "1")
    let otherLine = makeRoute(id: "metro-4", shortName: "4")
    let item = StationMapItem(
      id: StationID(rawValue: "interchange"),
      name: "Châtelet",
      coordinate: GeoCoordinate(latitude: 48.8567, longitude: 2.3522),
      routes: [line, otherLine]
    )
    let board = DepartureBoard(
      source: .theoretical,
      generatedAt: now,
      groups: [
        DepartureGroup(
          route: line,
          destination: "La Défense",
          departureItems: [
            DepartureItem(
              id: "line-late",
              scheduledAt: now.addingTimeInterval(600),
              expectedAt: nil,
              delaySeconds: nil,
              status: .scheduled
            ),
            DepartureItem(
              id: "line-first",
              scheduledAt: now.addingTimeInterval(300),
              expectedAt: nil,
              delaySeconds: nil,
              status: .scheduled
            ),
          ]
        ),
        DepartureGroup(
          route: otherLine,
          destination: "Bagneux",
          departures: [now.addingTimeInterval(420)],
          status: .scheduled
        ),
      ]
    )
    let repository = DelayedSelectedDeparturesRepository(
      boards: [item.id: board]
    )
    let model = makeModel(departures: repository, now: now)

    model.select(item)
    await waitUntil { model.loadingState == .loaded }

    model.selectLine(line)
    await waitUntil { model.lineScheduleLoadingState == .loaded }

    XCTAssertEqual(model.lineScheduleRoute?.id, line.id)
    XCTAssertEqual(model.lineScheduleSource, .theoretical)
    XCTAssertEqual(model.lineScheduleDepartures.map(\.id), ["line-first", "line-late"])
    XCTAssertEqual(
      model.lineScheduleTimetable.rows.map(\.id),
      ["direction-La Défense", "passage-line-first", "passage-line-late"]
    )
    let requestedRoutes = await repository.requestedRoutes()
    XCTAssertEqual(requestedRoutes, [line.id])

    model.clearLineSchedule()

    XCTAssertTrue(model.lineScheduleTimetable.isEmpty)
  }

  func testFailedDepartureRefreshKeepsStationAndOffersRetryState() async {
    let route = makeRoute(id: "metro-1", shortName: "1")
    let item = makeItem(id: "station", route: route)
    let model = makeModel(
      departures: FailingSelectedDeparturesRepository(),
      now: .now
    )

    model.select(item)
    await waitUntil {
      model.loadingState == .failed(.unavailable)
    }

    XCTAssertEqual(model.overview?.id, item.id)
    XCTAssertEqual(model.loadingState, .failed(.unavailable))
  }

  func testObsoleteDepartureResponseCannotReplaceNewSelection() async {
    let now = Date(timeIntervalSince1970: 2_000_000)
    let route = makeRoute(id: "metro-1", shortName: "1")
    let slow = makeItem(id: "slow", route: route)
    let current = makeItem(id: "current", route: route)
    let repository = DelayedSelectedDeparturesRepository(
      boards: [
        slow.id: DepartureBoard(source: .theoretical, generatedAt: now, groups: []),
        current.id: DepartureBoard(source: .realtime, generatedAt: now, groups: []),
      ],
      slowStationID: slow.id
    )
    let model = makeModel(departures: repository, now: now)

    model.select(slow)
    model.select(current)
    await waitUntil { model.overview?.departureSource == .realtime }
    try? await Task.sleep(for: .milliseconds(70))

    XCTAssertEqual(model.overview?.id, current.id)
    XCTAssertEqual(model.overview?.departureSource, .realtime)
  }

  func testCrowdingProfileLoadsOnSelectionAndClearsOnDismiss() async {
    let route = makeRoute(id: "metro-1", shortName: "1")
    let item = makeItem(id: "crowded", route: route)
    let model = makeModel(
      departures: InMemoryDeparturesRepository(),
      crowding: InMemoryStationCrowdingRepository(crowding: .preview),
      now: .now
    )

    model.select(item)
    XCTAssertFalse(model.isCrowdingLoaded)

    await waitUntil { model.isCrowdingLoaded }
    XCTAssertEqual(model.crowding, .preview)

    model.dismiss()
    XCTAssertNil(model.crowding)
    XCTAssertFalse(model.isCrowdingLoaded)
  }

  func testStationWithoutProfileLoadsAsEmptyCrowding() async {
    let route = makeRoute(id: "bus-38", shortName: "38")
    let item = makeItem(id: "bus-stop", route: route)
    let model = makeModel(
      departures: InMemoryDeparturesRepository(),
      crowding: InMemoryStationCrowdingRepository(crowding: nil),
      now: .now
    )

    model.select(item)
    await waitUntil { model.isCrowdingLoaded }

    XCTAssertNil(model.crowding)
  }

  func testCrowdingFailureDegradesSilently() async {
    let route = makeRoute(id: "metro-1", shortName: "1")
    let item = makeItem(id: "offline", route: route)
    let model = makeModel(
      departures: InMemoryDeparturesRepository(),
      crowding: FailingStationCrowdingRepository(),
      now: .now
    )

    model.select(item)
    await waitUntil { model.isCrowdingLoaded }

    XCTAssertNil(model.crowding)
    XCTAssertEqual(model.loadingState, .loaded)
  }

  func testFavoriteMutationIsPersistedByAccountModel() {
    let route = makeRoute(id: "metro-1", shortName: "1")
    let item = makeItem(id: "favorite", route: route)
    let (model, account) = makeModelAndAccount(
      departures: InMemoryDeparturesRepository()
    )
    model.select(item)

    XCTAssertFalse(model.isFavorite)
    XCTAssertTrue(model.toggleFavorite())
    XCTAssertTrue(account.isFavorite(stationID: item.id))
    XCTAssertTrue(model.isFavorite)

    XCTAssertFalse(model.toggleFavorite())
    XCTAssertFalse(account.isFavorite(stationID: item.id))
  }

  func testVisibleDetailLoadsLiveStatusImmediatelyAndStopsWhenCancelled() async {
    let route = makeRoute(id: "metro-1", shortName: "1")
    let item = makeItem(id: "live", route: route)
    let reports = SelectedStationReportRepository(statuses: [
      item.id: .empty(stationID: item.id)
    ])
    let model = makeModel(
      departures: InMemoryDeparturesRepository(),
      reports: reports,
      now: .now
    )
    model.select(item)

    let polling = Task { await model.observeLiveStatusWhileVisible() }
    await waitUntil { model.liveStatus?.stationId == item.id.rawValue }
    polling.cancel()
    await polling.value

    let requestedStations = await reports.requestedStations()
    XCTAssertEqual(requestedStations, [item.id])
  }

  func testObsoleteLiveStatusCannotReplaceANewerStation() async {
    let route = makeRoute(id: "metro-1", shortName: "1")
    let slow = makeItem(id: "slow-live", route: route)
    let current = makeItem(id: "current-live", route: route)
    let reports = SelectedStationReportRepository(
      statuses: [slow.id: .empty(stationID: slow.id), current.id: .empty(stationID: current.id)],
      slowStationID: slow.id
    )
    let model = makeModel(
      departures: InMemoryDeparturesRepository(),
      reports: reports,
      now: .now
    )

    model.select(slow)
    let oldPolling = Task { await model.observeLiveStatusWhileVisible() }
    model.select(current)
    let currentPolling = Task { await model.observeLiveStatusWhileVisible() }
    await waitUntil { model.liveStatus?.stationId == current.id.rawValue }
    try? await Task.sleep(for: .milliseconds(70))
    oldPolling.cancel()
    currentPolling.cancel()

    XCTAssertEqual(model.liveStatus?.stationId, current.id.rawValue)
  }

  private func makeModel(
    departures: any DeparturesRepository,
    crowding: any StationCrowdingRepository = InMemoryStationCrowdingRepository(),
    reports: any ReportRepository = InMemoryReportRepository(),
    now: Date
  ) -> SelectedStationModel {
    makeModelAndAccount(departures: departures, crowding: crowding, reports: reports, now: now).0
  }

  private func makeModelAndAccount(
    departures: any DeparturesRepository,
    crowding: any StationCrowdingRepository = InMemoryStationCrowdingRepository(),
    reports: any ReportRepository = InMemoryReportRepository(),
    now: Date = .now
  ) -> (SelectedStationModel, AccountModel) {
    let defaults = UserDefaults(suiteName: UUID().uuidString)!
    let account = AccountModel(
      store: AccountLocalStore(defaults: defaults),
      remote: InMemoryAccountRemote(),
      synchronizationEnabled: false,
      now: { now }
    )
    account.activateAnonymous()
    let location = LocationModel(
      adapter: InMemoryLocationAdapter(
        coordinate: GeoCoordinate(latitude: 48.8566, longitude: 2.3522)
      )
    )
    return (
      SelectedStationModel(
        departuresRepository: departures,
        crowdingRepository: crowding,
        reportRepository: reports,
        account: account,
        locationModel: location,
        now: { now }
      ),
      account
    )
  }

  private func makeRoute(id: String, shortName: String) -> RouteBadge {
    RouteBadge(
      id: RouteID(rawValue: id),
      shortName: shortName,
      mode: .metro,
      colorHex: "#FFBE00",
      textColorHex: "#000000"
    )
  }

  private func makeItem(id: String, route: RouteBadge) -> StationMapItem {
    StationMapItem(
      id: StationID(rawValue: id),
      name: id.capitalized,
      coordinate: GeoCoordinate(latitude: 48.8567, longitude: 2.3522),
      routes: [route],
      accessibility: StationAccessibility(
        condition: .autonomous,
        label: "En autonomie",
        comment: nil
      ),
      fountains: StationFountains(
        status: .available,
        label: "Fontaine d’eau potable à proximité",
        detail: "Accessible PMR"
      )
    )
  }

  private func waitUntil(
    _ predicate: @MainActor () -> Bool
  ) async {
    for _ in 0..<200 {
      if predicate() { return }
      try? await Task.sleep(for: .milliseconds(1))
    }
    XCTFail("Timed out waiting for selected station state")
  }
}

private actor SelectedStationReportRepository: ReportRepository {
  let statuses: [StationID: StationLiveStatus]
  let slowStationID: StationID?
  private var requests: [StationID] = []

  init(statuses: [StationID: StationLiveStatus], slowStationID: StationID? = nil) {
    self.statuses = statuses
    self.slowStationID = slowStationID
  }

  func submit(_ submission: ReportSubmission) async throws -> StationLiveStatus {
    statuses[submission.context.station.id] ?? .empty(stationID: submission.context.station.id)
  }

  func stationStatus(
    stationID: StationID,
    lineID: RouteID?,
    vehicleID: String?
  ) async throws -> StationLiveStatus {
    requests.append(stationID)
    try await Task.sleep(for: stationID == slowStationID ? .milliseconds(50) : .milliseconds(2))
    return statuses[stationID] ?? .empty(stationID: stationID)
  }

  func requestedStations() -> [StationID] { requests }
}

private actor DelayedSelectedDeparturesRepository: DeparturesRepository {
  let boards: [StationID: DepartureBoard]
  let slowStationID: StationID?
  private var routeRequests: [RouteID] = []

  init(
    boards: [StationID: DepartureBoard],
    slowStationID: StationID? = nil
  ) {
    self.boards = boards
    self.slowStationID = slowStationID
  }

  func board(stationID: StationID) async throws -> DepartureBoard {
    try await Task.sleep(
      for: stationID == slowStationID ? .milliseconds(50) : .milliseconds(2)
    )
    return boards[stationID]
      ?? DepartureBoard(source: .unavailable, generatedAt: .now, groups: [])
  }

  func board(stationID: StationID, routeID: RouteID) async throws -> DepartureBoard {
    routeRequests.append(routeID)
    return try await board(stationID: stationID)
  }

  func requestedRoutes() -> [RouteID] { routeRequests }
}

private struct FailingSelectedDeparturesRepository: DeparturesRepository {
  func board(stationID: StationID) async throws -> DepartureBoard {
    throw ViaError.unavailable
  }
}

private struct FailingStationCrowdingRepository: StationCrowdingRepository {
  func crowding(stationID: StationID) async throws -> StationCrowding? {
    throw ViaError.unavailable
  }
}
