import XCTest
@testable import Via

final class MeetupProgressResolverTests: XCTestCase {
    private let departure = Date(timeIntervalSince1970: 1_788_111_200)

    func testPublishesOnlyTransitProgressNearARealStop() throws {
        let meetup = makeMeetup(joinAt: departure.addingTimeInterval(10 * 60))
        let sample = LocationSample(
            coordinate: middle.coordinate,
            horizontalAccuracy: 10,
            recordedAt: departure.addingTimeInterval(5 * 60)
        )

        let progress = try XCTUnwrap(MeetupProgressResolver.resolve(
            meetup: meetup,
            sample: sample,
            previous: nil,
            now: sample.recordedAt
        ))

        XCTAssertEqual(progress.status, .underway)
        XCTAssertEqual(progress.sectionId, "transit")
        XCTAssertEqual(progress.serviceId, "service:canonical")
        XCTAssertEqual(progress.station?.id, middle.id)
    }

    func testDetectsAMissedDepartureFromTheActualBoardingFix() throws {
        let meetup = makeMeetup()
        let sample = LocationSample(
            coordinate: origin.coordinate,
            horizontalAccuracy: 10,
            recordedAt: departure.addingTimeInterval(3 * 60)
        )

        let progress = try XCTUnwrap(MeetupProgressResolver.resolve(
            meetup: meetup,
            sample: sample,
            previous: nil,
            now: sample.recordedAt
        ))

        XCTAssertEqual(progress.status, .missed)
        XCTAssertEqual(progress.station, origin)
        XCTAssertEqual(progress.serviceId, "service:canonical")
    }

    func testMarksAProgressiveJoinOnlyOnTheCanonicalServiceAtTheStation() throws {
        let sample = LocationSample(
            coordinate: middle.coordinate,
            horizontalAccuracy: 10,
            recordedAt: departure.addingTimeInterval(8 * 60)
        )
        let joined = try XCTUnwrap(MeetupProgressResolver.resolve(
            meetup: makeMeetup(joinAt: departure.addingTimeInterval(7 * 60)),
            sample: sample,
            previous: nil,
            now: sample.recordedAt
        ))
        let otherService = try XCTUnwrap(MeetupProgressResolver.resolve(
            meetup: makeMeetup(
                joinServiceID: "service:lookalike",
                joinAt: departure.addingTimeInterval(7 * 60)
            ),
            sample: sample,
            previous: nil,
            now: sample.recordedAt
        ))

        XCTAssertEqual(joined.status, .joined)
        XCTAssertEqual(otherService.status, .underway)
    }

    func testArrivalUsesTheRealDestinationFixAndEndsProgress() throws {
        let meetup = makeMeetup()
        let sample = LocationSample(
            coordinate: destination.coordinate,
            horizontalAccuracy: 12,
            recordedAt: departure.addingTimeInterval(18 * 60)
        )

        let progress = try XCTUnwrap(MeetupProgressResolver.resolve(
            meetup: meetup,
            sample: sample,
            previous: nil,
            now: sample.recordedAt
        ))

        XCTAssertEqual(progress.status, .arrived)
        XCTAssertEqual(progress.station, destination)
    }

    func testNeverAdvancesFromAStaleFix() {
        let meetup = makeMeetup()
        let sample = LocationSample(
            coordinate: middle.coordinate,
            horizontalAccuracy: 10,
            recordedAt: departure.addingTimeInterval(5 * 60)
        )

        XCTAssertNil(MeetupProgressResolver.resolve(
            meetup: meetup,
            sample: sample,
            previous: nil,
            now: sample.recordedAt.addingTimeInterval(31)
        ))
    }

    private var origin: MeetupStation {
        MeetupStation(
            id: "station:a",
            name: "Station A",
            coordinate: GeoCoordinate(latitude: 48.8566, longitude: 2.3522)
        )
    }

    private var middle: MeetupStation {
        MeetupStation(
            id: "station:b",
            name: "Station B",
            coordinate: GeoCoordinate(latitude: 48.8610, longitude: 2.3420)
        )
    }

    private var destination: MeetupStation {
        MeetupStation(
            id: "station:c",
            name: "Station C",
            coordinate: GeoCoordinate(latitude: 48.8660, longitude: 2.3320)
        )
    }

    private func makeMeetup(
        joinServiceID: String = "service:canonical",
        joinAt: Date? = nil
    ) -> Meetup {
        let participant = MeetupParticipant(
            id: "participant:alice",
            displayName: "Alice",
            role: .organizer,
            state: .underway,
            shareLevel: .progressOnly,
            zone: .middle,
            firstBoardingStation: origin,
            departureAt: departure,
            arrivalAt: departure.addingTimeInterval(20 * 60),
            createdAt: departure.addingTimeInterval(-3_600),
            updatedAt: departure
        )
        let other = MeetupParticipant(
            id: "participant:bob",
            displayName: "Bob",
            role: .member,
            state: .underway,
            shareLevel: .progressOnly,
            zone: .front,
            firstBoardingStation: middle,
            departureAt: departure,
            arrivalAt: departure.addingTimeInterval(20 * 60),
            createdAt: departure.addingTimeInterval(-3_600),
            updatedAt: departure
        )
        let journey = Journey(
            id: JourneyID(rawValue: "journey:alice"),
            qualifier: .recommended,
            durationSeconds: 20 * 60,
            walkingDurationSeconds: 0,
            transferCount: 0,
            departureAt: departure,
            arrivalAt: departure.addingTimeInterval(20 * 60),
            status: .normal,
            warnings: [],
            sections: [
                JourneySection(
                    id: "transit",
                    serviceID: "service:canonical",
                    kind: .transit,
                    durationSeconds: 20 * 60,
                    from: JourneyPlace(name: origin.name, coordinate: origin.coordinate),
                    to: JourneyPlace(name: destination.name, coordinate: destination.coordinate),
                    departureAt: departure,
                    arrivalAt: departure.addingTimeInterval(20 * 60),
                    geometry: [origin.coordinate, middle.coordinate, destination.coordinate],
                    route: JourneyRoute(
                        id: RouteID(rawValue: "route:1"),
                        shortName: "1",
                        longName: "Métro 1",
                        mode: .metro,
                        colorHex: "FFCD00",
                        textColorHex: "000000"
                    ),
                    direction: destination.name,
                    platform: "1",
                    stops: [
                        JourneyStop(
                            id: middle.id,
                            stationID: StationID(rawValue: middle.id),
                            name: middle.name,
                            coordinate: middle.coordinate,
                            arrivalAt: departure.addingTimeInterval(8 * 60),
                            departureAt: departure.addingTimeInterval(8 * 60)
                        ),
                    ]
                ),
            ]
        )
        let joinPoints = joinAt.map { date in
            [MeetupJoinPoint(
                id: "join:b",
                station: middle,
                serviceId: joinServiceID,
                meetAt: date,
                participantIds: [participant.id, other.id],
                zone: .middle
            )]
        } ?? []
        let plan = MeetupPlan(
            revision: 1,
            status: .ready,
            generatedAt: departure.addingTimeInterval(-600),
            isStale: false,
            warning: nil,
            participantJourneys: [
                MeetupParticipantJourney(
                    participantId: participant.id,
                    departureAt: journey.departureAt,
                    arrivalAt: journey.arrivalAt,
                    firstBoardingStation: origin,
                    journey: journey
                ),
            ],
            joinPoints: joinPoints
        )
        return Meetup(
            id: "meetup:1",
            destination: destination,
            targetArrivalAt: journey.arrivalAt,
            phase: .live,
            revision: 2,
            keyRevision: 1,
            currentParticipantId: participant.id,
            isOrganizer: true,
            participants: [participant, other],
            plan: plan,
            invitations: [],
            createdAt: departure.addingTimeInterval(-3_600),
            updatedAt: departure
        )
    }
}
