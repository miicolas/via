import Foundation
import XCTest
@testable import Via

final class SearchRemoteModelsTests: XCTestCase {
  func testBikeStationResultDecodesAsItsOwnKind() throws {
    let json = #"""
    {
      "results": [{
        "kind": "bikeStation",
        "id": "1",
        "name": "Hôtel de Ville",
        "coordinate": { "latitude": 48.8569, "longitude": 2.3522 },
        "capacity": 35,
        "availability": {
          "mechanicalBikes": 4,
          "electricBikes": 3,
          "docks": 28,
          "isInstalled": true,
          "isRenting": true,
          "isReturning": true
        }
      }],
      "sources": {
        "ban": "ok",
        "accessibility": { "status": "unavailable" },
        "elevators": { "status": "unavailable" },
        "velib": "ok"
      }
    }
    """#

    let response = try JSONDecoder.via
      .decode(SearchResponseDTO.self, from: Data(json.utf8))
      .domain()

    guard case .bikeStation(let result) = response.results.first else {
      return XCTFail("Expected a Vélib result")
    }
    XCTAssertEqual(result.id, "1")
    XCTAssertEqual(result.capacity, 35)
    XCTAssertEqual(result.availability?.totalBikes, 7)
    XCTAssertEqual(result.inventoryDetail, "7 vélos · 28 bornettes")
    XCTAssertEqual(response.bikeSource, .ok)
  }

  func testAddressResultNoLongerCarriesAnInventory() throws {
    let json = #"""
    {
      "results": [{
        "kind": "address",
        "id": "75104_8321_00012",
        "name": "12 Rue de Rivoli",
        "context": "75004 Paris",
        "coordinate": { "latitude": 48.8569, "longitude": 2.3522 }
      }],
      "sources": {
        "ban": "ok",
        "accessibility": { "status": "unavailable" },
        "elevators": { "status": "unavailable" },
        "velib": "unavailable"
      }
    }
    """#

    let response = try JSONDecoder.via
      .decode(SearchResponseDTO.self, from: Data(json.utf8))
      .domain()

    guard case .address(let result) = response.results.first else {
      return XCTFail("Expected an address result")
    }
    XCTAssertEqual(result.subtitle, "75004 Paris")
    XCTAssertEqual(response.bikeSource, .unavailable)
  }
}
