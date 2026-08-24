import XCTest
@testable import Via

final class StationMapFilterTests: XCTestCase {
  func testNoCriteriaMatchesEveryStation() {
    let filter = StationMapFilter()

    XCTAssertTrue(filter.matches(station()))
  }

  func testFacilityCriteriaMatchTheirOwnStationFacts() {
    let accessible = station(
      accessibility: StationAccessibility(
        condition: .reservationRequired,
        label: "Sur réservation",
        comment: nil
      )
    )
    let withElevators = station(hasElevators: true)
    let withToilets = station(
      toilets: StationToilets(label: "Sanitaires disponibles", detail: nil)
    )

    XCTAssertTrue(StationMapFilter(criteria: [.accessibility]).matches(accessible))
    XCTAssertFalse(StationMapFilter(criteria: [.accessibility]).matches(withElevators))
    XCTAssertTrue(StationMapFilter(criteria: [.elevators]).matches(withElevators))
    XCTAssertFalse(StationMapFilter(criteria: [.elevators]).matches(withToilets))
    XCTAssertTrue(StationMapFilter(criteria: [.toilets]).matches(withToilets))
    XCTAssertFalse(StationMapFilter(criteria: [.toilets]).matches(accessible))
  }

  func testEveryTransitModeCriterionMatchesItsMode() {
    for mode in TransitMode.allCases {
      let filter = StationMapFilter(criteria: [.mode(mode)])

      XCTAssertTrue(filter.matches(station(modes: [mode])))
      XCTAssertFalse(filter.matches(station(modes: TransitMode.allCases.filter { $0 != mode })))
    }
  }

  func testTransitModesCollectsOnlyModeCriteria() {
    XCTAssertEqual(StationMapFilter().transitModes, [])
    XCTAssertEqual(StationMapFilter(criteria: [.toilets, .bikeStations]).transitModes, [])
    XCTAssertEqual(
      StationMapFilter(criteria: [.mode(.metro), .mode(.tram), .toilets]).transitModes,
      [.metro, .tram]
    )
  }

  func testBikeStationsStayHiddenUntilTheVelibFilterIsSelected() {
    let bike = StationMapItem(bikeStation: BikeStation(
      id: "1",
      stationCode: "04001",
      name: "Hôtel de Ville",
      coordinate: GeoCoordinate(latitude: 48.8569, longitude: 2.3522),
      capacity: 35,
      availability: nil
    ))

    XCTAssertFalse(StationMapFilter().matches(bike))
    XCTAssertTrue(StationMapFilter(criteria: [.bikeStations]).matches(bike))
    XCTAssertFalse(StationMapFilter(criteria: [.mode(.metro)]).matches(bike))
  }

  func testMultipleCriteriaUseOrSemanticsAndResetRestoresAllStations() {
    var filter = StationMapFilter(criteria: [.accessibility, .mode(.bus)])

    XCTAssertTrue(filter.matches(station(
      modes: [.metro],
      accessibility: StationAccessibility(
        condition: .autonomous,
        label: "En autonomie",
        comment: nil
      )
    )))
    XCTAssertTrue(filter.matches(station(modes: [.bus])))
    XCTAssertFalse(filter.matches(station(modes: [.tram])))

    filter.reset()

    XCTAssertFalse(filter.isActive)
    XCTAssertTrue(filter.matches(station(modes: [.tram])))
  }

  private func station(
    modes: [TransitMode] = [],
    accessibility: StationAccessibility? = nil,
    hasElevators: Bool = false,
    toilets: StationToilets? = nil
  ) -> StationMapItem {
    StationMapItem(
      id: StationID(rawValue: "station"),
      name: "Station",
      coordinate: GeoCoordinate(latitude: 48.85, longitude: 2.35),
      routes: modes.enumerated().map { index, mode in
        RouteBadge(
          id: RouteID(rawValue: "\(mode.rawValue)-\(index)"),
          shortName: "\(index)",
          mode: mode,
          colorHex: "#000000",
          textColorHex: "#FFFFFF"
        )
      },
      accessibility: accessibility,
      hasElevators: hasElevators,
      toilets: toilets
    )
  }
}

extension StationMapFilterTests {
  func testFilterSurvivesAnEncodeDecodeRoundTrip() throws {
    var filter = StationMapFilter()
    filter.criteria = [.toilets, .bikeStations, .mode(.rer)]

    let data = try JSONEncoder().encode(filter)
    let restored = try JSONDecoder().decode(StationMapFilter.self, from: data)

    XCTAssertEqual(restored, filter)
  }

  /// A criterion this build no longer knows must cost only itself: the rest of
  /// a stored filter still comes back.
  func testUnknownStoredCriteriaAreDroppedRatherThanFailingTheWholeFilter() throws {
    let stored = Data(#"{"criteria":["toilets","mode.hovercraft","teleportation"]}"#.utf8)

    let restored = try JSONDecoder().decode(StationMapFilter.self, from: stored)

    XCTAssertEqual(restored.criteria, [.toilets])
  }

  @MainActor
  func testStoreRestoresWhatWasSavedAndTellsItsObservers() {
    let persistence = InMemoryStationMapFilterPersistence()
    let store = StationMapFilterStore(persistence: persistence)
    var notified: [StationMapFilter] = []
    store.onChange { notified.append($0) }

    store.filter.criteria = [.elevators]

    XCTAssertEqual(notified.map(\.criteria), [[.elevators]])
    XCTAssertEqual(
      StationMapFilterStore(persistence: persistence).filter.criteria,
      [.elevators]
    )
  }
}
