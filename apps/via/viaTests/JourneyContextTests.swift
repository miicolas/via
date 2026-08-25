import XCTest
@testable import Via

final class JourneyContextTests: XCTestCase {
    func testResolverUsesActiveReminderPlannedSearchPrecedence() {
        let journey = JourneyResult.mapPreview.journeys[0]
        let destination = JourneyDestination.address(
            id: "destination",
            name: "La Défense",
            context: nil,
            coordinate: GeoCoordinate(latitude: 48.8918, longitude: 2.2380)
        )
        let context = JourneyContext(
            journey: journey,
            destination: destination,
            source: .realtime,
            planningPolicy: JourneyPlanningPolicy()
        )

        let resolved = JourneyContextResolver.resolve(
            journeyID: journey.id,
            active: context,
            reminder: context,
            planned: context,
            search: context
        )

        XCTAssertEqual(resolved, context)
    }

    func testJourneyShapeRecognisesAWalkingOnlyJourney() {
        let base = JourneyResult.mapPreview.journeys[0]
        let walking = base.identified(as: JourneyID(rawValue: "walking-only"))
        let directSections = base.sections.filter { $0.kind == .walk || $0.kind == .bike }
        let direct = Journey(
            id: walking.id,
            qualifier: walking.qualifier,
            durationSeconds: walking.durationSeconds,
            walkingDurationSeconds: walking.walkingDurationSeconds,
            transferCount: 0,
            departureAt: walking.departureAt,
            arrivalAt: walking.arrivalAt,
            status: walking.status,
            warnings: walking.warnings,
            sections: directSections
        )

        XCTAssertEqual(JourneyShape.of(direct), .walking)
        XCTAssertTrue(JourneyShape.of(direct).isDirectPath)
        XCTAssertFalse(JourneyShape.of(direct).isBikeOnly)
    }
}
