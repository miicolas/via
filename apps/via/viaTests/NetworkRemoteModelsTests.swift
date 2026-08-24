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
