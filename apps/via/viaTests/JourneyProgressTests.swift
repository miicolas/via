import XCTest
@testable import Via

final class JourneyProgressTests: XCTestCase {
    private let referenceDate = Date(timeIntervalSince1970: 2_000_000_000)

    // A straight west-to-east line, so a fraction along it is also a fraction
    // of the longitude span — easy to reason about in assertions.
    private let west = GeoCoordinate(latitude: 48.8600, longitude: 2.3000)
    private let east = GeoCoordinate(latitude: 48.8600, longitude: 2.4000)

    func testFractionFallsBackToScheduleInterpolationWithoutAFix() {
        let journey = makeJourney()
        let schedule = ActiveJourneyRules.schedule(for: journey)

        let progress = JourneyProgressProjector.progress(
            schedule: schedule,
            sectionIndex: 0,
            at: referenceDate.addingTimeInterval(300),
            coordinate: nil,
            horizontalAccuracy: nil
        )

        XCTAssertFalse(progress.isLocationDerived)
        XCTAssertEqual(progress.fractionInSection, 0.5, accuracy: 0.001)
    }

    func testScheduleInterpolationIsClampedOutsideTheSection() {
        let schedule = ActiveJourneyRules.schedule(for: makeJourney())

        let before = JourneyProgressProjector.progress(
            schedule: schedule,
            sectionIndex: 0,
            at: referenceDate.addingTimeInterval(-600),
            coordinate: nil,
            horizontalAccuracy: nil
        )
        let after = JourneyProgressProjector.progress(
            schedule: schedule,
            sectionIndex: 0,
            at: referenceDate.addingTimeInterval(6_000),
            coordinate: nil,
            horizontalAccuracy: nil
        )

        XCTAssertEqual(before.fractionInSection, 0)
        XCTAssertEqual(after.fractionInSection, 1)
    }

    func testALocationFixOnTheLineOverridesTheSchedule() {
        let schedule = ActiveJourneyRules.schedule(for: makeJourney())
        let quarterOfTheWay = GeoCoordinate(latitude: 48.8600, longitude: 2.3250)

        // The schedule says the leg is over; the traveller is a quarter in.
        let progress = JourneyProgressProjector.progress(
            schedule: schedule,
            sectionIndex: 0,
            at: referenceDate.addingTimeInterval(6_000),
            coordinate: quarterOfTheWay,
            horizontalAccuracy: 10
        )

        XCTAssertTrue(progress.isLocationDerived)
        XCTAssertEqual(progress.fractionInSection, 0.25, accuracy: 0.01)
    }

    func testAFixFarFromTheLineIsIgnored() {
        let schedule = ActiveJourneyRules.schedule(for: makeJourney())
        // Roughly 1.1 km north of the line — well beyond the arrival radius.
        let offRoute = GeoCoordinate(latitude: 48.8700, longitude: 2.3250)

        let progress = JourneyProgressProjector.progress(
            schedule: schedule,
            sectionIndex: 0,
            at: referenceDate.addingTimeInterval(300),
            coordinate: offRoute,
            horizontalAccuracy: 10
        )

        XCTAssertFalse(progress.isLocationDerived)
        XCTAssertEqual(progress.fractionInSection, 0.5, accuracy: 0.001)
    }

    func testSectionIndexIsClampedToTheSchedule() {
        let schedule = ActiveJourneyRules.schedule(for: makeJourney())

        let progress = JourneyProgressProjector.progress(
            schedule: schedule,
            sectionIndex: 99,
            at: referenceDate,
            coordinate: nil,
            horizontalAccuracy: nil
        )

        XCTAssertEqual(progress.sectionIndex, schedule.count - 1)
    }

    func testOverallFractionWeightsSectionsByDuration() {
        let schedule = ActiveJourneyRules.schedule(for: makeJourney())

        // Section 0 lasts 600 s, section 1 lasts 300 s: 900 s in total.
        let halfwayThroughTheSecondSection = JourneyProgressProjector.progress(
            schedule: schedule,
            sectionIndex: 1,
            at: referenceDate.addingTimeInterval(600 + 150),
            coordinate: nil,
            horizontalAccuracy: nil
        )

        XCTAssertEqual(halfwayThroughTheSecondSection.overallFraction, 750.0 / 900.0, accuracy: 0.001)
    }

    func testStopsUntilAlightingCountsDownFromTheTimetableWithoutAFix() {
        let schedule = ActiveJourneyRules.schedule(for: makeJourney())

        // Boarding, then three calls at 200 s, 400 s and 600 s.
        let afterTwoCalls = JourneyProgressProjector.progress(
            schedule: schedule,
            sectionIndex: 0,
            at: referenceDate.addingTimeInterval(450),
            coordinate: nil,
            horizontalAccuracy: nil
        )

        XCTAssertEqual(afterTwoCalls.passedStopCount, 2)
        XCTAssertEqual(afterTwoCalls.stopsUntilAlighting, 1)
    }

    func testStopsUntilAlightingUsesGeometryWhenAFixIsAvailable() {
        let schedule = ActiveJourneyRules.schedule(for: makeJourney())
        // Past the second call (2.3667) but before the third (2.4).
        let pastTheSecondCall = GeoCoordinate(latitude: 48.8600, longitude: 2.3800)

        let progress = JourneyProgressProjector.progress(
            schedule: schedule,
            sectionIndex: 0,
            at: referenceDate,
            coordinate: pastTheSecondCall,
            horizontalAccuracy: 10
        )

        XCTAssertTrue(progress.isLocationDerived)
        XCTAssertEqual(progress.passedStopCount, 2)
        XCTAssertEqual(progress.stopsUntilAlighting, 1)
    }

    func testWalkingSectionHasNoStopCountdown() {
        let schedule = ActiveJourneyRules.schedule(for: makeJourney())

        let progress = JourneyProgressProjector.progress(
            schedule: schedule,
            sectionIndex: 1,
            at: referenceDate.addingTimeInterval(700),
            coordinate: nil,
            horizontalAccuracy: nil
        )

        XCTAssertNil(progress.stopsUntilAlighting)
        XCTAssertEqual(progress.passedStopCount, 0)
    }

    func testProjectedCoordinateFollowsTheLineWithoutAFix() {
        let schedule = ActiveJourneyRules.schedule(for: makeJourney())

        let progress = JourneyProgressProjector.progress(
            schedule: schedule,
            sectionIndex: 0,
            at: referenceDate.addingTimeInterval(300),
            coordinate: nil,
            horizontalAccuracy: nil
        )

        XCTAssertEqual(progress.projectedCoordinate?.longitude ?? 0, 2.35, accuracy: 0.002)
    }

    // MARK: - Splitting

    func testSplitCutsTheLineInTwoAtTheGivenFraction() {
        let line = [west, GeoCoordinate(latitude: 48.86, longitude: 2.35), east]

        let split = JourneyProgressProjector.split(coordinates: line, at: 0.5)

        XCTAssertEqual(split.traveled.first?.longitude ?? 0, 2.30, accuracy: 0.001)
        XCTAssertEqual(split.traveled.last?.longitude ?? 0, 2.35, accuracy: 0.002)
        XCTAssertEqual(split.remaining.first?.longitude ?? 0, 2.35, accuracy: 0.002)
        XCTAssertEqual(split.remaining.last?.longitude ?? 0, 2.40, accuracy: 0.001)
    }

    func testSplitAtTheEdgesKeepsTheWholeLineOnOneSide() {
        let line = [west, east]

        let atStart = JourneyProgressProjector.split(coordinates: line, at: 0)
        let atEnd = JourneyProgressProjector.split(coordinates: line, at: 1)

        XCTAssertTrue(atStart.traveled.isEmpty)
        XCTAssertEqual(atStart.remaining.count, 2)
        XCTAssertEqual(atEnd.traveled.count, 2)
        XCTAssertTrue(atEnd.remaining.isEmpty)
    }

    func testSplitOfADegenerateLineIsLeftUntouched() {
        let split = JourneyProgressProjector.split(coordinates: [west], at: 0.5)

        XCTAssertTrue(split.traveled.isEmpty)
        XCTAssertEqual(split.remaining, [west])
    }

    // MARK: - Fixtures

    /// A transit section along a straight line, with three calls after boarding,
    /// followed by a short walk.
    private func makeJourney() -> Journey {
        let boarding = JourneyPlace(name: "Ouest", coordinate: west)
        let alighting = JourneyPlace(name: "Est", coordinate: east)

        let ride = JourneySection(
            id: "section:0",
            kind: .transit,
            durationSeconds: 600,
            from: boarding,
            to: alighting,
            departureAt: referenceDate,
            arrivalAt: referenceDate.addingTimeInterval(600),
            geometry: [west, east],
            route: JourneyRoute(
                id: RouteID(rawValue: "route:1"),
                shortName: "1",
                longName: "Métro 1",
                mode: .metro,
                colorHex: "FFCE00",
                textColorHex: "000000"
            ),
            direction: "Est",
            platform: nil,
            stops: [
                stop(id: "b", name: "Ouest", longitude: 2.3000, at: 0),
                stop(id: "c1", name: "Un tiers", longitude: 2.3333, at: 200),
                stop(id: "c2", name: "Deux tiers", longitude: 2.3667, at: 400),
                stop(id: "a", name: "Est", longitude: 2.4000, at: 600),
            ]
        )

        let walk = JourneySection(
            id: "section:1",
            kind: .walk,
            durationSeconds: 300,
            from: alighting,
            to: JourneyPlace(
                name: "Destination",
                coordinate: GeoCoordinate(latitude: 48.8620, longitude: 2.4020)
            ),
            departureAt: nil,
            arrivalAt: nil,
            geometry: [],
            route: nil,
            direction: nil,
            platform: nil,
            stops: []
        )

        return Journey(
            id: JourneyID(rawValue: "test:progress"),
            qualifier: .recommended,
            durationSeconds: 900,
            walkingDurationSeconds: 300,
            transferCount: 0,
            departureAt: referenceDate,
            arrivalAt: referenceDate.addingTimeInterval(900),
            status: .normal,
            warnings: [],
            sections: [ride, walk]
        )
    }

    private func stop(id: String, name: String, longitude: Double, at offset: TimeInterval) -> JourneyStop {
        JourneyStop(
            id: id,
            name: name,
            coordinate: GeoCoordinate(latitude: 48.8600, longitude: longitude),
            arrivalAt: referenceDate.addingTimeInterval(offset),
            departureAt: referenceDate.addingTimeInterval(offset)
        )
    }
}

final class JourneyTimelineStateTests: XCTestCase {
    private let referenceDate = Date(timeIntervalSince1970: 2_000_000_000)

    func testWithoutProgressEveryNodeReadsAsUpcoming() {
        let journey = Journey.mapPreviewMultipleTransfers
        let nodes = JourneyTimeline.nodes(for: journey)

        XCTAssertTrue(nodes.allSatisfy { JourneyTimeline.state(of: $0, progress: nil) == .upcoming })
        XCTAssertNil(JourneyTimeline.cursor(in: nodes, progress: nil))
    }

    func testPassedSectionsAreDoneAndLaterOnesUpcoming() {
        let journey = Journey.mapPreviewMultipleTransfers
        let nodes = JourneyTimeline.nodes(for: journey)
        let progress = makeProgress(sectionIndex: 2, fraction: 0.5)

        for node in nodes {
            let state = JourneyTimeline.state(of: node, progress: progress)
            if node.sectionIndex < 2 {
                XCTAssertEqual(state, .done, "\(node.id) should be behind the traveller")
            } else if node.sectionIndex > 2 {
                XCTAssertEqual(state, .upcoming, "\(node.id) should still be ahead")
            }
        }
    }

    func testBoardingBecomesDoneOnceTheLegHasStarted() {
        let journey = Journey.mapPreviewMultipleTransfers
        let nodes = JourneyTimeline.nodes(for: journey)
        guard let boarding = nodes.first(where: {
            if case .board = $0.kind { return true } else { return false }
        }) else { return XCTFail("expected a boarding node") }

        let atTheDoor = makeProgress(sectionIndex: boarding.sectionIndex, fraction: 0)
        let underway = makeProgress(sectionIndex: boarding.sectionIndex, fraction: 0.3)

        XCTAssertEqual(JourneyTimeline.state(of: boarding, progress: atTheDoor), .current)
        XCTAssertEqual(JourneyTimeline.state(of: boarding, progress: underway), .done)
    }

    func testCursorSitsOnTheMovementRowOfTheCurrentSection() {
        let journey = Journey.mapPreviewMultipleTransfers
        let nodes = JourneyTimeline.nodes(for: journey)
        let progress = makeProgress(sectionIndex: 0, fraction: 0.4)

        guard let cursor = JourneyTimeline.cursor(in: nodes, progress: progress) else {
            return XCTFail("expected a cursor")
        }
        guard let host = nodes.first(where: { $0.id == cursor.nodeID }) else {
            return XCTFail("cursor points at an unknown node")
        }

        XCTAssertEqual(host.sectionIndex, 0)
        XCTAssertEqual(cursor.fraction, 0.4, accuracy: 0.001)
        switch host.kind {
        case .walk, .wait, .transfer, .ride, .board:
            break
        default:
            XCTFail("the cursor must not sit on \(host.id)")
        }
    }

    private func makeProgress(sectionIndex: Int, fraction: Double) -> JourneyProgress {
        JourneyProgress(
            sectionIndex: sectionIndex,
            fractionInSection: fraction,
            overallFraction: fraction,
            passedStopCount: 0,
            stopsUntilAlighting: nil,
            projectedCoordinate: nil,
            isLocationDerived: false
        )
    }
}

final class JourneyGuidanceTests: XCTestCase {
    private let referenceDate = Date(timeIntervalSince1970: 2_000_000_000)

    func testPausedJourneyOverridesEverythingElse() {
        let journey = Journey.mapPreviewMultipleTransfers

        let headline = JourneyGuidance.headline(
            journey: journey,
            schedule: ActiveJourneyRules.schedule(for: journey),
            progress: .start,
            at: journey.departureAt.addingTimeInterval(300),
            isPaused: true
        )

        XCTAssertEqual(headline.title, "Trajet en pause")
    }

    func testBeforeDepartureItCountsDown() {
        let journey = Journey.mapPreviewMultipleTransfers

        let headline = JourneyGuidance.headline(
            journey: journey,
            schedule: ActiveJourneyRules.schedule(for: journey),
            progress: .start,
            at: journey.departureAt.addingTimeInterval(-5 * 60),
            isPaused: false
        )

        XCTAssertTrue(headline.title.hasPrefix("Départ dans"), headline.title)
    }

    func testRidingPhrasesTheAlightingCountdown() {
        let journey = makeRidingJourney()
        let schedule = ActiveJourneyRules.schedule(for: journey)

        let three = headline(journey: journey, schedule: schedule, stopsUntilAlighting: 3)
        let one = headline(journey: journey, schedule: schedule, stopsUntilAlighting: 1)
        let zero = headline(journey: journey, schedule: schedule, stopsUntilAlighting: 0)

        XCTAssertEqual(three.title, "Descendre dans 3 arrêts")
        XCTAssertEqual(one.title, "Descendre au prochain arrêt")
        XCTAssertEqual(zero.title, "Descendre maintenant")
        XCTAssertEqual(three.alightStopName, "Est")
        XCTAssertEqual(three.stopsUntilAlighting, 3)
        XCTAssertNotNil(three.route)
    }

    func testALegWithoutStopListStillNamesWhereToGetOff() {
        let journey = makeRidingJourney(withStops: false)
        let schedule = ActiveJourneyRules.schedule(for: journey)

        let result = headline(journey: journey, schedule: schedule, stopsUntilAlighting: nil)

        XCTAssertEqual(result.title, "Descendre à Est")
    }

    private func headline(
        journey: Journey,
        schedule: [JourneySectionSchedule],
        stopsUntilAlighting: Int?
    ) -> JourneyGuidanceHeadline {
        JourneyGuidance.headline(
            journey: journey,
            schedule: schedule,
            progress: JourneyProgress(
                sectionIndex: 0,
                fractionInSection: 0.5,
                overallFraction: 0.5,
                passedStopCount: 0,
                stopsUntilAlighting: stopsUntilAlighting,
                projectedCoordinate: nil,
                isLocationDerived: true
            ),
            at: journey.departureAt.addingTimeInterval(120),
            isPaused: false
        )
    }

    private func makeRidingJourney(withStops: Bool = true) -> Journey {
        let west = GeoCoordinate(latitude: 48.86, longitude: 2.30)
        let east = GeoCoordinate(latitude: 48.86, longitude: 2.40)
        let names = ["Ouest", "Arrêt 1", "Arrêt 2", "Arrêt 3", "Est"]
        let stops: [JourneyStop] = names.indices.map { index in
            let offset: Double = Double(index)
            let longitude: Double = 2.30 + offset * 0.025
            let time: Date = referenceDate.addingTimeInterval(offset * 150)
            return JourneyStop(
                id: "stop:\(index)",
                name: names[index],
                coordinate: GeoCoordinate(latitude: 48.86, longitude: longitude),
                arrivalAt: time,
                departureAt: time
            )
        }

        let section = JourneySection(
            id: "section:0",
            kind: .transit,
            durationSeconds: 600,
            from: JourneyPlace(name: "Ouest", coordinate: west),
            to: JourneyPlace(name: "Est", coordinate: east),
            departureAt: referenceDate,
            arrivalAt: referenceDate.addingTimeInterval(600),
            geometry: [west, east],
            route: JourneyRoute(
                id: RouteID(rawValue: "route:1"),
                shortName: "1",
                longName: "Métro 1",
                mode: .metro,
                colorHex: "FFCE00",
                textColorHex: "000000"
            ),
            direction: "Est",
            platform: nil,
            stops: withStops ? stops : []
        )

        return Journey(
            id: JourneyID(rawValue: "test:riding"),
            qualifier: .recommended,
            durationSeconds: 600,
            walkingDurationSeconds: 0,
            transferCount: 0,
            departureAt: referenceDate,
            arrivalAt: referenceDate.addingTimeInterval(600),
            status: .normal,
            warnings: [],
            sections: [section]
        )
    }
}
