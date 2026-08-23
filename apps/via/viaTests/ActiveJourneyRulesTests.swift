import XCTest
@testable import Via

final class ActiveJourneyRulesTests: XCTestCase {
    private let referenceDate = Date(timeIntervalSince1970: 2_000_000_000)

    func testActivationTitleUsesConfirmedTenMinuteBoundary() {
        let imminent = makeJourney(departureAt: referenceDate.addingTimeInterval(10 * 60))
        let future = makeJourney(departureAt: referenceDate.addingTimeInterval(10 * 60 + 1))

        XCTAssertEqual(
            ActiveJourneyRules.activationAction(for: imminent, now: referenceDate),
            .go
        )
        XCTAssertEqual(
            ActiveJourneyRules.activationAction(for: future, now: referenceDate),
            .plan
        )
    }

    func testManualOriginOffersPlanEvenWhenDepartureIsImminent() {
        XCTAssertEqual(
            ActiveJourneyRules.detailAction(
                activeAction: .go,
                isPlanned: false,
                prefersGo: false,
                prefersPlan: true
            ),
            .plan
        )
    }

    func testOpeningAPlannedDraftOffersGoAndAnActiveSessionStillWins() {
        XCTAssertEqual(
            ActiveJourneyRules.detailAction(
                activeAction: .plan,
                isPlanned: true,
                prefersGo: true,
                prefersPlan: true
            ),
            .go
        )
        XCTAssertEqual(
            ActiveJourneyRules.detailAction(
                activeAction: .resume,
                isPlanned: true,
                prefersGo: true,
                prefersPlan: true
            ),
            .resume
        )
    }

    func testSavedDraftIsPresentedAsPlannedOutsideItsLaunchSurface() {
        XCTAssertEqual(
            ActiveJourneyRules.detailAction(
                activeAction: .plan,
                isPlanned: true,
                prefersGo: false,
                prefersPlan: false
            ),
            .planned
        )
    }

    func testScheduleInfersMissingSectionTimesFromDurations() {
        let journey = makeJourney(departureAt: referenceDate)

        let schedule = ActiveJourneyRules.schedule(for: journey)

        XCTAssertEqual(schedule.map(\.startsAt), [
            referenceDate,
            referenceDate.addingTimeInterval(5 * 60),
            referenceDate.addingTimeInterval(15 * 60),
        ])
        XCTAssertEqual(schedule.last?.endsAt, referenceDate.addingTimeInterval(20 * 60))
    }

    func testProgressAndMonitoringCadenceWakeAtTheExactTransition() {
        let journey = makeJourney(departureAt: referenceDate)

        XCTAssertEqual(
            ActiveJourneyRules.sectionIndex(in: journey, at: referenceDate.addingTimeInterval(6 * 60)),
            1
        )
        XCTAssertEqual(
            ActiveJourneyRules.nextMonitoringDelay(in: journey, at: referenceDate.addingTimeInterval(11 * 60)),
            120
        )
        XCTAssertEqual(
            ActiveJourneyRules.nextMonitoringDelay(in: journey, at: referenceDate.addingTimeInterval(13 * 60)),
            30
        )
        XCTAssertEqual(
            ActiveJourneyRules.nextMonitoringDelay(in: journey, at: referenceDate.addingTimeInterval(4 * 60 + 50)),
            10
        )
    }

    func testRestorationExpiresThirtyMinutesAfterPlannedArrival() {
        let journey = makeJourney(departureAt: referenceDate)

        XCTAssertTrue(
            ActiveJourneyRules.isExpired(journey, at: journey.arrivalAt.addingTimeInterval(30 * 60))
        )
        XCTAssertEqual(
            ActiveJourneyRules.nextMonitoringDelay(
                in: journey,
                at: journey.arrivalAt.addingTimeInterval(30 * 60 - 10)
            ),
            10
        )
    }

    func testZeroDurationIsNotPresentedAsOneMinute() {
        XCTAssertEqual(JourneyFormatting.duration(0), "0 min")
    }

    func testArrivalRadiusAdaptsToAccuracyWithoutExceedingTwoHundredMeters() {
        XCTAssertEqual(ActiveJourneyRules.arrivalRadius(horizontalAccuracy: 20), 75)
        XCTAssertEqual(ActiveJourneyRules.arrivalRadius(horizontalAccuracy: 80), 160)
        XCTAssertEqual(ActiveJourneyRules.arrivalRadius(horizontalAccuracy: 500), 200)
        XCTAssertEqual(ActiveJourneyRules.arrivalRadius(horizontalAccuracy: nil), 150)
    }

    func testConnectionIsCompromisedOnlyAfterGracePeriodAndAwayFromBoardingPoint() {
        let journey = makeJourney(departureAt: referenceDate)
        let transit = ActiveJourneyRules.schedule(for: journey)[1]
        let farAway = GeoCoordinate(latitude: 48.8600, longitude: 2.3500)
        let nearby = journey.sections[1].from.coordinate

        XCTAssertFalse(ActiveJourneyRules.isConnectionCompromised(
            schedule: transit,
            coordinate: farAway,
            now: transit.startsAt.addingTimeInterval(119)
        ))
        XCTAssertFalse(ActiveJourneyRules.isConnectionCompromised(
            schedule: transit,
            coordinate: nearby,
            now: transit.startsAt.addingTimeInterval(121)
        ))
        XCTAssertTrue(ActiveJourneyRules.isConnectionCompromised(
            schedule: transit,
            coordinate: farAway,
            now: transit.startsAt.addingTimeInterval(120)
        ))
    }

    private func makeJourney(departureAt: Date) -> Journey {
        let origin = JourneyPlace(
            name: "Origine",
            coordinate: GeoCoordinate(latitude: 48.8566, longitude: 2.3522)
        )
        let interchange = JourneyPlace(
            name: "Correspondance",
            coordinate: GeoCoordinate(latitude: 48.8584, longitude: 2.3470)
        )
        let destination = JourneyPlace(
            name: "Destination",
            coordinate: GeoCoordinate(latitude: 48.8918, longitude: 2.2380)
        )
        let route = JourneyRoute(
            id: RouteID(rawValue: "test:metro:1"),
            shortName: "1",
            longName: "Métro 1",
            mode: .metro,
            colorHex: "FFCD00",
            textColorHex: "000000"
        )
        let arrivalAt = departureAt.addingTimeInterval(20 * 60)

        return Journey(
            id: JourneyID(rawValue: "test:journey"),
            qualifier: .recommended,
            durationSeconds: 20 * 60,
            walkingDurationSeconds: 10 * 60,
            transferCount: 0,
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
                    id: "transit",
                    kind: .transit,
                    durationSeconds: 10 * 60,
                    from: interchange,
                    to: destination,
                    departureAt: nil,
                    arrivalAt: nil,
                    geometry: [],
                    route: route,
                    direction: "Destination",
                    platform: "1",
                    stops: []
                ),
                JourneySection(
                    id: "walk-end",
                    kind: .walk,
                    durationSeconds: 5 * 60,
                    from: destination,
                    to: destination,
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
