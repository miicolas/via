import XCTest
@testable import Via

final class NetworkViewportAnnotationTests: XCTestCase {
  func testOverviewUsesCompactAnnotationsAndCloseZoomUsesDetails() {
    XCTAssertTrue(viewport(spanMeters: 12_000).usesCompactStationAnnotations)
    XCTAssertTrue(viewport(spanMeters: 1_400).usesCompactStationAnnotations)
    XCTAssertFalse(viewport(spanMeters: 800).usesCompactStationAnnotations)
  }

  func testTransitMapItemsKeepEveryTransitModeAvailableForSelection() {
    let routes = TransitMode.allCases.enumerated().map { index, mode in
      RouteBadge(
        id: RouteID(rawValue: "route-\(index)"),
        shortName: "\(index)",
        mode: mode,
        colorHex: "#000000",
        textColorHex: "#FFFFFF"
      )
    }
    let station = NetworkStation(
      id: StationID(rawValue: "all-modes"),
      name: "Station multimodale",
      coordinate: GeoCoordinate(latitude: 48.8566, longitude: 2.3522),
      routeIDs: routes.map(\.id)
    )

    let item = StationsArea(stations: [station], routes: routes).transitMapItems.first

    XCTAssertEqual(item?.routes.count, TransitMode.allCases.count)
    XCTAssertEqual(item.map { Set($0.routes.map(\.mode)) }, Set(TransitMode.allCases))
  }

  func testNearbyRadiusMustCoverEveryViewportCorner() {
    XCTAssertTrue(viewport(spanMeters: 2_000).fitsInside(radiusMeters: 2_000))
    XCTAssertFalse(viewport(spanMeters: 4_000).fitsInside(radiusMeters: 2_000))
  }

  func testSparseSharedVehiclesGroupOnlyWhenTheMapIsDezoomed() {
    let bike1 = sharedVehicle(
      id: "bike-1",
      provider: .dott,
      mode: .bicycle,
      latitude: 48.85
    )
    let bike2 = sharedVehicle(
      id: "bike-2",
      provider: .dott,
      mode: .bicycle,
      latitude: 48.8502
    )
    let scooter = sharedVehicle(
      id: "scooter-1",
      provider: .yego,
      mode: .scooter,
      latitude: 48.8502
    )
    let items = [bike1, bike2, scooter].map(StationMapItem.init(sharedMobility:))

    let close = items.groupedSharedMobility(for: viewport(spanMeters: 800))
    XCTAssertEqual(close.count, 3)
    XCTAssertTrue(close.allSatisfy { $0.sharedMobilityCluster == nil })

    let overview = items.groupedSharedMobility(for: viewport(spanMeters: 1_200))
    XCTAssertEqual(overview.count, 2)
    XCTAssertEqual(
      overview.first(where: { $0.sharedMobilityCluster != nil })?.sharedMobilityCluster?.count,
      2
    )
    XCTAssertTrue(overview.contains { $0.id.rawValue == "mobility:scooter-1" })
  }

  func testDenseColocatedVehiclesCollapseEvenAtCloseZoom() {
    let vehicles = (1...120).map { index in
      sharedVehicle(
        id: "bike-\(index)",
        provider: .lime,
        mode: .bicycle,
        latitude: 48.85
      )
    }
    let items = vehicles.map(StationMapItem.init(sharedMobility:))

    let annotations = items.groupedSharedMobility(for: viewport(spanMeters: 800))

    XCTAssertEqual(annotations.count, 1)
    XCTAssertEqual(annotations.first?.sharedMobilityCluster?.count, 120)
  }

  func testSharedMobilityUsesDistinctVehicleSymbols() {
    let kickScooter = sharedVehicle(
      id: "dott-scooter",
      provider: .dott,
      mode: .scooter,
      latitude: 48.85
    )
    let moped = sharedVehicle(
      id: "yego-scooter",
      provider: .yego,
      mode: .scooter,
      latitude: 48.85
    )

    XCTAssertEqual(kickScooter.systemImage, "scooter")
    XCTAssertEqual(moped.systemImage, "moped")

    let cluster = SharedMobilityCluster(
      id: "yego-cluster",
      coordinate: GeoCoordinate(latitude: 48.85, longitude: 2.35),
      provider: .yego,
      mode: .scooter,
      count: 2
    )
    XCTAssertEqual(cluster.systemImage, "moped")
  }

  private func viewport(spanMeters: Double) -> NetworkViewport {
    NetworkViewport(
      center: GeoCoordinate(latitude: 48.85, longitude: 2.35),
      latitudeDelta: spanMeters / 111_000,
      longitudeDelta: spanMeters / 111_000,
      width: 390,
      height: 844
    )
  }

  private func sharedVehicle(
    id: String,
    provider: SharedMobilityProvider,
    mode: SharedMobilityMode,
    latitude: Double
  ) -> SharedMobilityItem {
    .vehicle(SharedMobilityVehicle(
      id: id,
      provider: provider,
      mode: mode,
      coordinate: GeoCoordinate(latitude: latitude, longitude: 2.35)
    ))
  }
}
