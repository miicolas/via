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

    func testARealFixAtAStationMarksThatStationAsCurrent() {
        let stops = makeStops()

        let progress = JourneyLocationMatcher.stopProgress(
            sectionID: "section:rer-a",
            stops: stops,
            path: stops.map(\.coordinate),
            to: stops[1].coordinate,
            horizontalAccuracy: 10
        )

        XCTAssertEqual(progress?.sectionID, "section:rer-a")
        XCTAssertEqual(progress?.stopID, "station:b")
        XCTAssertEqual(progress?.status, .current)
        XCTAssertEqual(progress?.stopIndex, 1)
        XCTAssertEqual(progress?.stopCount, 3)
        XCTAssertEqual(progress?.remainingStopCount, 1)
    }

    func testARealFixBetweenStationsMovesTheDiodeToTheNextStation() {
        let stops = makeStops()

        let progress = JourneyLocationMatcher.stopProgress(
            sectionID: "section:rer-a",
            stops: stops,
            path: stops.map(\.coordinate),
            to: GeoCoordinate(latitude: 48.85, longitude: 2.33),
            horizontalAccuracy: 10
        )

        XCTAssertEqual(progress?.stopID, "station:c")
        XCTAssertEqual(progress?.status, .next)
    }

    func testAnOffRouteFixDoesNotLightAStation() {
        let stops = makeStops()

        let progress = JourneyLocationMatcher.stopProgress(
            sectionID: "section:rer-a",
            stops: stops,
            path: stops.map(\.coordinate),
            to: GeoCoordinate(latitude: 49.1, longitude: 2.9),
            horizontalAccuracy: 10
        )

        XCTAssertNil(progress)
    }

    func testPenultimateStationMakesTheAlightingAlertActionable() throws {
        let stops = makeStops()
        let progress = try XCTUnwrap(JourneyLocationMatcher.stopProgress(
            sectionID: "section:rer-a",
            stops: stops,
            path: stops.map(\.coordinate),
            to: stops[1].coordinate,
            horizontalAccuracy: 10
        ))

        XCTAssertTrue(JourneyLocationMatcher.shouldAlertForAlighting(
            progress: progress,
            coordinate: stops[1].coordinate
        ))
    }

    func testDirectServiceWaitsUntilItIsCloseToTheAlightingStop() throws {
        let stops = [makeStops().first!, makeStops().last!]
        let farCoordinate = GeoCoordinate(latitude: 48.85, longitude: 2.31)
        let nearCoordinate = GeoCoordinate(latitude: 48.85, longitude: 2.335)
        let farProgress = try XCTUnwrap(JourneyLocationMatcher.stopProgress(
            sectionID: "section:express",
            stops: stops,
            path: stops.map(\.coordinate),
            to: farCoordinate,
            horizontalAccuracy: 10
        ))
        let nearProgress = try XCTUnwrap(JourneyLocationMatcher.stopProgress(
            sectionID: "section:express",
            stops: stops,
            path: stops.map(\.coordinate),
            to: nearCoordinate,
            horizontalAccuracy: 10
        ))

        XCTAssertFalse(JourneyLocationMatcher.shouldAlertForAlighting(
            progress: farProgress,
            coordinate: farCoordinate
        ))
        XCTAssertTrue(JourneyLocationMatcher.shouldAlertForAlighting(
            progress: nearProgress,
            coordinate: nearCoordinate
        ))
    }

    private func makeJourney() -> Journey {
        JourneyResult.mapPreview.journeys[0]
    }

    private func makeStops() -> [JourneyStop] {
        [
            stop(id: "station:a", longitude: 2.30),
            stop(id: "station:b", longitude: 2.32),
            stop(id: "station:c", longitude: 2.34),
        ]
    }

    private func stop(id: String, longitude: Double) -> JourneyStop {
        JourneyStop(
            id: id,
            name: id,
            coordinate: GeoCoordinate(latitude: 48.85, longitude: longitude),
            arrivalAt: nil,
            departureAt: nil
        )
    }
}
