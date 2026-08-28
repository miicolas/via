import XCTest
@testable import Via

final class JourneyLocationMatcherTests: XCTestCase {
    func testARealFixOnTheRouteSelectsItsSection() {
        let journey = makeJourney()
        let schedule = ActiveJourneyRules.schedule(for: journey)

        let index = JourneyLocationMatcher.nearestSectionIndex(
            schedule: schedule,
            to: journey.sections[0].from.coordinate,
            horizontalAccuracy: 10
        )

        XCTAssertEqual(index, 0)
    }

    func testARealFixFarFromTheRouteIsIgnored() {
        let journey = makeJourney()
        let schedule = ActiveJourneyRules.schedule(for: journey)

        let index = JourneyLocationMatcher.nearestSectionIndex(
            schedule: schedule,
            to: GeoCoordinate(latitude: 49.1, longitude: 2.9),
            horizontalAccuracy: 10
        )

        XCTAssertNil(index)
    }

    private func makeJourney() -> Journey {
        JourneyResult.mapPreview.journeys[0]
    }
}
