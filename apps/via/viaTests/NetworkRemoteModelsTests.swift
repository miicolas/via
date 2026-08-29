import Foundation
import XCTest
@testable import Via

final class NetworkRemoteModelsTests: XCTestCase {
  func testStationDecodesElevatorPresence() throws {
    let station = try decodeStation(extraJSON: #", "hasElevators": true"#)

    XCTAssertTrue(station.domain().hasElevators)
  }

  func testLegacyStationWithoutElevatorFieldDefaultsToFalse() throws {
    let station = try decodeStation()

    XCTAssertFalse(station.domain().hasElevators)
  }

  func testStationDecodesDrinkingWaterFountain() throws {
    let station = try decodeStation(
      extraJSON: #", "fountains": {"status": "available", "label": "Fontaine d’eau potable à proximité", "detail": "Accessible PMR"}"#
    )

    XCTAssertEqual(station.domain().fountains?.status, .available)
    XCTAssertEqual(station.domain().fountains?.detail, "Accessible PMR")
  }

  func testStationIgnoresUnknownFountainStatus() throws {
    let station = try decodeStation(
      extraJSON: #", "fountains": {"status": "unknown", "label": "Fontaine"}"#
    )

    XCTAssertNil(station.domain().fountains)
  }

  func testBikeAreaDecodesLiveAvailability() throws {
    let json = #"""
    {
      "bikeStations": [{
        "id": "1",
        "stationCode": "04001",
        "name": "Hôtel de Ville",
        "coordinate": { "latitude": 48.8569, "longitude": 2.3522 },
        "capacity": 35,
        "availability": {
          "mechanicalBikes": 4,
          "electricBikes": 3,
          "docks": 28,
          "isInstalled": true,
          "isRenting": true,
          "isReturning": true,
          "lastReportedAt": "2026-08-24T09:32:14Z"
        }
      }],
      "sources": { "velib": "ok" }
    }
    """#

    let area = try JSONDecoder.via
      .decode(BikeStationsAreaDTO.self, from: Data(json.utf8))
      .domain

    XCTAssertTrue(area.sourceAvailable)
    XCTAssertEqual(area.stations.first?.availability?.totalBikes, 7)
    XCTAssertEqual(area.stations.first?.availability?.docks, 28)
  }

  func testBikeAreaWithoutSourcesReadsAsUnavailable() throws {
    let json = #"{ "bikeStations": [] }"#

    let area = try JSONDecoder.via
      .decode(BikeStationsAreaDTO.self, from: Data(json.utf8))
      .domain

    XCTAssertFalse(area.sourceAvailable)
    XCTAssertTrue(area.stations.isEmpty)
  }

  func testSharedMobilityAreaDecodesVehiclesStationsSourcesAndOptionalFields() throws {
    let json = #"""
    {
      "items": [
        {
          "kind": "vehicle",
          "id": "dott:paris:bike-1",
          "provider": "dott",
          "mode": "bicycle",
          "vehicleType": "Vélo électrique",
          "availability": "available",
          "coordinate": { "latitude": 48.85, "longitude": 2.35 },
          "batteryPercent": 64,
          "rangeMeters": 12000,
          "lastReportedAt": "2026-08-26T09:59:00Z",
          "restriction": "no-ride",
          "rentalUrl": "dott://bike-1",
          "operatorUrl": "https://ridedott.com/"
        },
        {
          "kind": "station",
          "id": "velib:42",
          "provider": "velib",
          "name": "Hôtel de Ville",
          "coordinate": { "latitude": 48.8569, "longitude": 2.3522 },
          "stationCode": "04001",
          "capacity": 35,
          "availability": {
            "mechanicalBikes": 4,
            "electricBikes": 3,
            "docks": 28,
            "isInstalled": true,
            "isRenting": true,
            "isReturning": true,
            "lastReportedAt": "2026-08-26T09:59:00Z"
          },
          "operatorUrl": "https://www.velib-metropole.fr/"
        }
      ],
      "sources": {
        "dott": {
          "status": "ok",
          "sourceUpdatedAt": "2026-08-26T09:59:00Z",
          "expiresAt": "2026-08-26T10:00:00Z"
        },
        "lime": { "status": "unavailable" },
        "velib": { "status": "ok" },
        "yego": { "status": "ok" }
      }
    }
    """#

    let area = try JSONDecoder.via
      .decode(SharedMobilityAreaDTO.self, from: Data(json.utf8))
      .domain()

    XCTAssertEqual(area.items.count, 2)
    guard case .vehicle(let vehicle) = area.items[0] else {
      return XCTFail("The first item should be a vehicle")
    }
    XCTAssertEqual(vehicle.provider, .dott)
    XCTAssertEqual(vehicle.mode, .bicycle)
    XCTAssertEqual(vehicle.batteryPercent, 64)
    XCTAssertEqual(vehicle.restriction, .noRide)
    XCTAssertEqual(
      vehicle.restriction?.message(for: vehicle.provider),
      "Zone de circulation restreinte selon Dott"
    )
    XCTAssertEqual(vehicle.rentalURL?.scheme, "dott")
    XCTAssertEqual(area.source(.lime).state, .unavailable)

    guard case .station(let station) = area.items[1] else {
      return XCTFail("The second item should be a station")
    }
    XCTAssertEqual(station.station.availability?.totalBikes, 7)
    XCTAssertEqual(station.station.availability?.docks, 28)
  }

  private func decodeStation(extraJSON: String = "") throws -> NetworkStationDTO {
    let json = """
    {
      "id": "station",
      "name": "Station",
      "coordinate": { "latitude": 48.85, "longitude": 2.35 },
      "routeIds": []\(extraJSON)
    }
    """
    return try JSONDecoder().decode(NetworkStationDTO.self, from: Data(json.utf8))
  }
}
