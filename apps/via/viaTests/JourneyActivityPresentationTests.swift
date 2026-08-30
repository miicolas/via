import XCTest
@testable import Via

final class JourneyActivityPresentationTests: XCTestCase {
    private let departureAt = Date(timeIntervalSince1970: 2_000_000_000)

    func testArrivedStateSpeaksOnlyTheDestination() {
        let state = JourneyActivityPresentation.contentState(
            session: makeSession(currentSectionIndex: 4),
            isArrived: true,
            requiresResume: false,
            isOffline: true,
            at: departureAt.addingTimeInterval(34 * 60)
        )

        XCTAssertEqual(state.phase, .arrived)
        XCTAssertEqual(state.phaseTitle, "Vous êtes arrivé")
        XCTAssertEqual(state.instructionTitle, "La Défense")
        XCTAssertNil(state.instructionDetail)
        XCTAssertNil(state.nextAction)
        XCTAssertNil(state.line)
        XCTAssertNil(state.nextLine)
        XCTAssertFalse(state.isOffline, "An arrived activity never claims to be offline")
        XCTAssertTrue(state.isArrived)
    }

    func testPausedStateKeepsThePausedSentenceAndTheOfflineFlag() {
        let state = JourneyActivityPresentation.contentState(
            session: makeSession(currentSectionIndex: 1),
            isArrived: false,
            requiresResume: true,
            isOffline: true,
            at: departureAt.addingTimeInterval(10 * 60)
        )

        XCTAssertEqual(state.phase, .paused)
        XCTAssertEqual(state.phaseTitle, "Trajet en pause")
        XCTAssertEqual(state.instructionTitle, "Trajet en pause")
        XCTAssertEqual(state.instructionDetail, "Reprenez pour relancer le suivi")
        XCTAssertTrue(state.isOffline)
    }

    func testScheduledStateLeavesTheCountdownToTheSystemTimer() {
        let state = JourneyActivityPresentation.contentState(
            session: makeSession(),
            isArrived: false,
            requiresResume: false,
            isOffline: false,
            at: departureAt.addingTimeInterval(-5 * 60)
        )

        XCTAssertEqual(state.phase, .scheduled)
        XCTAssertEqual(state.phaseTitle, "Départ")
        XCTAssertEqual(state.instructionTitle, "Trajet vers La Défense")
        XCTAssertEqual(state.departureAt, departureAt)
        XCTAssertEqual(state.arrivalAt, departureAt.addingTimeInterval(34 * 60))
    }

    func testRidingStateSaysTheSameSentenceAsTheGuidanceHeader() {
        let session = makeSession(currentSectionIndex: 1)
        let date = departureAt.addingTimeInterval(10 * 60)

        let state = JourneyActivityPresentation.contentState(
            session: session,
            isArrived: false,
            requiresResume: false,
            isOffline: false,
            at: date
        )
        let headline = JourneyGuidance.headline(
            journey: session.journey,
            schedule: ActiveJourneyRules.schedule(for: session.journey),
            sectionIndex: session.currentSectionIndex,
            at: date,
            isPaused: false
        )

        XCTAssertEqual(state.phase, .underway)
        XCTAssertEqual(state.phaseTitle, "En route")
        XCTAssertEqual(state.instructionTitle, headline.title)
        XCTAssertEqual(state.instructionDetail, headline.detail)
        XCTAssertTrue(
            state.instructionDetail?.contains("Voiture 2/8") == true,
            "Boarding advice survives into the lock screen: \(state.instructionDetail ?? "nil")"
        )
        XCTAssertEqual(state.line?.shortName, "1")
    }

    func testPenultimateStationTurnsTheLiveActivityIntoAnAlightingWarning() throws {
        let session = makeSession(currentSectionIndex: 1)
        let progress = makeStopProgress(
            status: .current,
            stopIndex: 1,
            stopName: "Châtelet"
        )

        let state = JourneyActivityPresentation.contentState(
            session: session,
            isArrived: false,
            requiresResume: false,
            isOffline: false,
            at: departureAt.addingTimeInterval(10 * 60),
            liveStopProgress: progress
        )
        let alert = try XCTUnwrap(JourneyActivityPresentation.alightingAlert(for: progress))

        XCTAssertEqual(state.instructionTitle, "Prochain arrêt · Gare de Lyon")
        XCTAssertTrue(state.instructionDetail?.contains("Préparez-vous à descendre") == true)
        XCTAssertEqual(state.stopProgress?.stopName, "Châtelet")
        XCTAssertEqual(state.stopProgress?.remainingStopCount, 1)
        XCTAssertEqual(alert.title, "Prochain arrêt · Gare de Lyon")
        XCTAssertEqual(alert.body, "Préparez-vous à descendre.")
    }

    func testAtAlightingStationSaysToGetOffNow() {
        let progress = makeStopProgress(
            status: .current,
            stopIndex: 2,
            stopName: "Gare de Lyon"
        )

        let state = JourneyActivityPresentation.contentState(
            session: makeSession(currentSectionIndex: 1),
            isArrived: false,
            requiresResume: false,
            isOffline: false,
            at: departureAt.addingTimeInterval(15 * 60),
            liveStopProgress: progress
        )

        XCTAssertEqual(state.instructionTitle, "Descendez maintenant · Gare de Lyon")
        XCTAssertEqual(state.stopProgress?.remainingStopCount, 0)
    }

    func testNextTransferStepReadsCorrespondanceWithItsDuration() {
        let session = makeSession(currentSectionIndex: 1)

        let next = JourneyActivityPresentation.nextInstruction(in: session)
        let state = JourneyActivityPresentation.contentState(
            session: session,
            isArrived: false,
            requiresResume: false,
            isOffline: false,
            at: departureAt.addingTimeInterval(10 * 60)
        )

        XCTAssertEqual(next?.title, "Rejoignez Gare de Lyon")
        XCTAssertEqual(next?.detail, "Correspondance · 4 min")
        XCTAssertEqual(state.nextAction, "Rejoignez Gare de Lyon")
        XCTAssertNil(state.nextLine, "A transfer has no line of its own")
    }

    func testWalkLegKeepsTheUpcomingLineBadgeWithoutRepeatingItOnEnsuite() {
        let state = JourneyActivityPresentation.contentState(
            session: makeSession(currentSectionIndex: 0),
            isArrived: false,
            requiresResume: false,
            isOffline: false,
            at: departureAt.addingTimeInterval(2 * 60)
        )

        XCTAssertEqual(
            state.line?.shortName,
            "1",
            "The badge survives the legs that have no route of their own"
        )
        XCTAssertNil(
            state.nextLine,
            "The Ensuite badge is dropped when it repeats the current line"
        )
    }

    func testTerminalStateEndsWithTheGivenTitle() {
        let session = makeSession(currentSectionIndex: 1)

        let state = JourneyActivityPresentation.terminal(
            title: "Trajet arrêté",
            session: session
        )

        XCTAssertEqual(state.phase, .ended)
        XCTAssertEqual(state.phaseTitle, "Trajet arrêté")
        XCTAssertEqual(state.instructionTitle, "La Défense")
        XCTAssertNil(state.instructionDetail)
        XCTAssertNil(state.nextAction)
        XCTAssertNil(state.line)
        XCTAssertEqual(state.arrivalAt, session.journey.arrivalAt)
        XCTAssertEqual(state.departureAt, session.journey.departureAt)
        XCTAssertFalse(state.isArrived)
    }

    func testStaleDateFollowsTheMonitoringCadenceWithAFloorOfFortyFiveSeconds() {
        let journey = makeJourney()

        let quiet = departureAt.addingTimeInterval(10 * 60)
        XCTAssertEqual(
            JourneyActivityPresentation.staleDate(for: journey, at: quiet),
            quiet.addingTimeInterval(180),
            "Standard cadence of 120 s stretches to 180 s of staleness"
        )

        let nearTransition = departureAt.addingTimeInterval(14 * 60)
        XCTAssertEqual(
            JourneyActivityPresentation.staleDate(for: journey, at: nearTransition),
            nearTransition.addingTimeInterval(45),
            "The 30 s transition cadence never undercuts the 45 s floor"
        )
    }

    private var destination: JourneyDestination {
        .address(
            id: "test:destination",
            name: "La Défense",
            context: "Puteaux",
            coordinate: GeoCoordinate(latitude: 48.8918, longitude: 2.2380)
        )
    }

    private func makeSession(currentSectionIndex: Int = 0) -> ActiveJourneySession {
        ActiveJourneySession(
            journey: makeJourney(),
            destination: destination,
            source: .realtime,
            planningPolicy: JourneyPlanningPolicy(),
            currentSectionIndex: currentSectionIndex,
            lastCoordinate: nil,
            horizontalAccuracy: nil,
            isTrackingStarted: true,
            allowsBackgroundTracking: false
        )
    }

    private func makeStopProgress(
        status: JourneyStopProgress.Status,
        stopIndex: Int,
        stopName: String
    ) -> JourneyStopProgress {
        JourneyStopProgress(
            sectionID: "metro",
            stopID: "metro:stop:\(stopIndex)",
            status: status,
            stopIndex: stopIndex,
            stopCount: 3,
            stopName: stopName,
            alightingStopName: "Gare de Lyon",
            alightingCoordinate: GeoCoordinate(latitude: 48.8443, longitude: 2.3744)
        )
    }

    /// Walk 5 min · Métro 1 for 10 min (voiture 2/8) · correspondance 4 min ·
    /// RER A for 10 min (sortie 3) · walk 5 min.
    private func makeJourney() -> Journey {
        let origin = JourneyPlace(
            name: "Origine",
            coordinate: GeoCoordinate(latitude: 48.8566, longitude: 2.3522)
        )
        let interchange = JourneyPlace(
            name: "Bastille",
            coordinate: GeoCoordinate(latitude: 48.8531, longitude: 2.3691)
        )
        let hub = JourneyPlace(
            name: "Gare de Lyon",
            coordinate: GeoCoordinate(latitude: 48.8443, longitude: 2.3744)
        )
        let destinationPlace = JourneyPlace(
            name: "La Défense",
            coordinate: GeoCoordinate(latitude: 48.8918, longitude: 2.2380)
        )
        let metro = JourneyRoute(
            id: RouteID(rawValue: "test:metro:1"),
            shortName: "1",
            longName: "Métro 1",
            mode: .metro,
            colorHex: "FFCD00",
            textColorHex: "000000"
        )
        let rer = JourneyRoute(
            id: RouteID(rawValue: "test:rer:a"),
            shortName: "A",
            longName: "RER A",
            mode: .rer,
            colorHex: "E2231A",
            textColorHex: "FFFFFF"
        )
        let arrivalAt = departureAt.addingTimeInterval(34 * 60)

        return Journey(
            id: JourneyID(rawValue: "test:journey"),
            qualifier: .recommended,
            durationSeconds: 34 * 60,
            walkingDurationSeconds: 14 * 60,
            transferCount: 1,
            departureAt: departureAt,
            arrivalAt: arrivalAt,
            status: .normal,
            warnings: [],
            sections: [
                JourneySection(
                    id: "walk-start",
                    kind: .walk,
                    durationSeconds: 5 * 60,
                    from: origin,
                    to: interchange,
                    departureAt: departureAt,
                    arrivalAt: nil,
                    geometry: [],
                    route: nil,
                    direction: nil,
                    platform: nil,
                    stops: []
                ),
                JourneySection(
                    id: "metro",
                    kind: .transit,
                    durationSeconds: 10 * 60,
                    from: interchange,
                    to: hub,
                    departureAt: nil,
                    arrivalAt: nil,
                    geometry: [],
                    route: metro,
                    direction: "Château de Vincennes",
                    platform: "1",
                    stops: [],
                    boardingPosition: JourneyBoardingPosition(
                        car: 2,
                        carCount: 8,
                        zone: .front,
                        reason: .transfer,
                        equipment: nil
                    )
                ),
                JourneySection(
                    id: "transfer",
                    kind: .transfer,
                    durationSeconds: 4 * 60,
                    from: hub,
                    to: hub,
                    departureAt: nil,
                    arrivalAt: nil,
                    geometry: [],
                    route: nil,
                    direction: nil,
                    platform: nil,
                    stops: []
                ),
                JourneySection(
                    id: "rer",
                    kind: .transit,
                    durationSeconds: 10 * 60,
                    from: hub,
                    to: destinationPlace,
                    departureAt: nil,
                    arrivalAt: nil,
                    geometry: [],
                    route: rer,
                    direction: "Saint-Germain-en-Laye",
                    platform: "2",
                    stops: [],
                    exit: JourneyExit(
                        id: "test:exit",
                        name: "Grande Arche",
                        number: 3,
                        coordinate: GeoCoordinate(latitude: 48.8925, longitude: 2.2360),
                        walkingMeters: 120
                    )
                ),
                JourneySection(
                    id: "walk-end",
                    kind: .walk,
                    durationSeconds: 5 * 60,
                    from: destinationPlace,
                    to: destinationPlace,
                    departureAt: nil,
                    arrivalAt: arrivalAt,
                    geometry: [],
                    route: nil,
                    direction: nil,
                    platform: nil,
                    stops: []
                ),
            ]
        )
    }
}
