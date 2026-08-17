import XCTest
@testable import Via

final class SearchTokenStateTests: XCTestCase {
    func testSelectingOriginKeepsDestinationQueryReadyForTheNextToken() {
        var draft = JourneyDraft()
        let origin = JourneyPlaceSelection.address(
            id: "origin",
            name: "SFO",
            context: "San Francisco",
            coordinate: GeoCoordinate(latitude: 37.6213, longitude: -122.3790)
        )

        draft.setPlace(origin, for: .origin)
        draft.setQuery("lax", for: .destination)

        XCTAssertEqual(draft.origin?.name, "SFO")
        XCTAssertEqual(draft.query(for: .destination), "lax")
    }
}
