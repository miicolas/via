import Foundation
import XCTest
@testable import Via

final class SearchRemoteModelsTests: XCTestCase {
  func testVelibAddressResultKeepsLiveAvailability() throws {
    let json = #"""
    {
      "results": [{
        "kind": "address",
        "id": "velib:1",
        "name": "Hôtel de Ville",
        "context": "Station Vélib’",
        "coordinate": { "latitude": 48.8569, "longitude": 2.3522 },
        "bikeStation": {
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

    guard case .address(let result) = response.results.first else {
      return XCTFail("Expected a Vélib address result")
    }
    XCTAssertTrue(result.isBikeStation)
    XCTAssertEqual(result.bikeStation?.totalBikes, 7)
    XCTAssertEqual(response.bikeSource, .ok)
  }
}
