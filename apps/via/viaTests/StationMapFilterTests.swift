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

  func testSharedMobilityCriteriaKeepBikesScootersAndStationsSeparate() {
    let bike = StationMapItem(sharedMobility: .vehicle(SharedMobilityVehicle(
      id: "dott-bike",
      provider: .dott,
      mode: .bicycle,
      coordinate: GeoCoordinate(latitude: 48.85, longitude: 2.35)
    )))
    let scooter = StationMapItem(sharedMobility: .vehicle(SharedMobilityVehicle(
      id: "yego-scooter",
      provider: .yego,
      mode: .scooter,
      coordinate: GeoCoordinate(latitude: 48.85, longitude: 2.35)
    )))
    let station = StationMapItem(sharedMobility: .station(SharedMobilityStation(
      station: BikeStation(
        id: "velib-station",
        stationCode: nil,
        name: "Hôtel de Ville",
        coordinate: GeoCoordinate(latitude: 48.85, longitude: 2.35),
        capacity: 35,
        availability: nil
      )
    )))

    XCTAssertTrue(StationMapFilter(criteria: [.sharedBikes]).matches(bike))
    XCTAssertFalse(StationMapFilter(criteria: [.sharedBikes]).matches(scooter))
    XCTAssertTrue(StationMapFilter(criteria: [.sharedScooters]).matches(scooter))
    XCTAssertFalse(StationMapFilter(criteria: [.sharedScooters]).matches(bike))
    XCTAssertTrue(StationMapFilter(criteria: [.bikeStations]).matches(station))
    XCTAssertFalse(StationMapFilter(criteria: [.sharedBikes]).matches(station))
  }

  func testScooterFilterRequestsDottAndYegoAndKeepsItsVisibleTitle() {
    let filter = StationMapFilter(criteria: [.sharedScooters])

    XCTAssertEqual(StationMapFilterCriterion.sharedScooters.title, "Scooters")
    XCTAssertEqual(SharedMobilityMode.scooter.displayName, "Scooter")
    XCTAssertEqual(filter.requestedSharedMobilityProviders, [.dott, .yego])
    XCTAssertEqual(SharedMobilityProvider.providers(for: .scooter), [.dott, .yego])

    let yego = SharedMobilityVehicle(
      id: "yego-scooter",
      provider: .yego,
      mode: .scooter,
      vehicleType: "Trottinette électrique",
      coordinate: GeoCoordinate(latitude: 48.85, longitude: 2.35)
    )
    XCTAssertEqual(yego.displayTypeName, "Scooter électrique")
  }

  func testExpiredSharedMobilityItemsAreNotCurrent() {
    let item = SharedMobilityItem.vehicle(SharedMobilityVehicle(
      id: "expired-bike",
      provider: .lime,
      mode: .bicycle,
      coordinate: GeoCoordinate(latitude: 48.85, longitude: 2.35)
    ))
    let area = SharedMobilityArea(
      items: [item],
      sources: [.lime: SharedMobilitySourceStatus(
        state: .ok,
        expiresAt: Date(timeIntervalSince1970: 100)
      )]
    )

    XCTAssertTrue(area.currentItems(at: Date(timeIntervalSince1970: 99)).isEmpty == false)
    XCTAssertTrue(area.currentItems(at: Date(timeIntervalSince1970: 100)).isEmpty)
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
