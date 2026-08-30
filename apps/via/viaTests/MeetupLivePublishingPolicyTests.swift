import XCTest
@testable import Via

final class MeetupLivePublishingPolicyTests: XCTestCase {
    func testRequiresFiveSecondsAndSignificantMovement() {
        let first = LocationSample(
            coordinate: GeoCoordinate(latitude: 48.8566, longitude: 2.3522),
            horizontalAccuracy: 10,
            recordedAt: Date(timeIntervalSince1970: 100)
        )
        let close = LocationSample(
            coordinate: GeoCoordinate(latitude: 48.85661, longitude: 2.3522),
            horizontalAccuracy: 10,
            recordedAt: Date(timeIntervalSince1970: 106)
        )
        let moved = LocationSample(
            coordinate: GeoCoordinate(latitude: 48.8570, longitude: 2.3522),
            horizontalAccuracy: 10,
            recordedAt: Date(timeIntervalSince1970: 106)
        )

        XCTAssertTrue(MeetupLivePublishingPolicy.shouldPublish(sample: first, after: nil, publishedAt: nil))
        XCTAssertFalse(MeetupLivePublishingPolicy.shouldPublish(sample: close, after: first, publishedAt: first.recordedAt))
        XCTAssertTrue(MeetupLivePublishingPolicy.shouldPublish(sample: moved, after: first, publishedAt: first.recordedAt))
    }

    func testAllLivePublicationsAreThrottledToFiveSeconds() {
        let previous = Date(timeIntervalSince1970: 100)

        XCTAssertEqual(
            MeetupLivePublishingPolicy.publicationDelay(
                after: previous,
                now: previous.addingTimeInterval(2)
            ),
            3
        )
        XCTAssertEqual(
            MeetupLivePublishingPolicy.publicationDelay(
                after: previous,
                now: previous.addingTimeInterval(5)
            ),
            0
        )
    }

    func testPrecisePresenceRejectsStaleAndImplausiblyFutureSamples() {
        let now = Date(timeIntervalSince1970: 200)
        let sample: (TimeInterval) -> LocationSample = { timestamp in
            LocationSample(
                coordinate: GeoCoordinate(latitude: 48.8566, longitude: 2.3522),
                horizontalAccuracy: 10,
                recordedAt: Date(timeIntervalSince1970: timestamp)
            )
        }

        XCTAssertTrue(MeetupLivePublishingPolicy.isFresh(sample: sample(170), now: now))
        XCTAssertTrue(MeetupLivePublishingPolicy.isFresh(sample: sample(205), now: now))
        XCTAssertFalse(MeetupLivePublishingPolicy.isFresh(sample: sample(169), now: now))
        XCTAssertFalse(MeetupLivePublishingPolicy.isFresh(sample: sample(206), now: now))
    }

    @MainActor
    func testArrivalEndsAnOffSessionImmediately() async {
        let now = Date()
        let participant = MeetupParticipant(
            id: "participant",
            displayName: "Alice",
            role: .organizer,
            state: .ready,
            shareLevel: .off,
            zone: .middle,
            firstBoardingStation: nil,
            departureAt: now,
            arrivalAt: now.addingTimeInterval(1_800),
            createdAt: now,
            updatedAt: now
        )
        let meetup = Meetup(
            id: "meetup",
            destination: MeetupStation(
                id: "destination",
                name: "Châtelet",
                coordinate: GeoCoordinate(latitude: 48.8583, longitude: 2.3470)
            ),
            targetArrivalAt: now.addingTimeInterval(1_800),
            phase: .ready,
            revision: 1,
            keyRevision: 1,
            currentParticipantId: participant.id,
            isOrganizer: true,
            participants: [participant],
            plan: nil,
            invitations: [],
            createdAt: now,
            updatedAt: now
        )
        let coordinator = MeetupLiveCoordinator(
            transport: InMemoryMeetupRepository(meetups: [meetup]),
            cryptography: MeetupCryptoVault(),
            locationModel: LocationModel(adapter: InMemoryLocationAdapter()),
            precisePresenceEnabled: { false }
        )

        await coordinator.start(meetup)
        XCTAssertTrue(coordinator.isActive)

        await coordinator.updateProgress(MeetupProgress(
            status: .arrived,
            sectionId: nil,
            serviceId: nil,
            station: meetup.destination,
            expectedAt: meetup.targetArrivalAt,
            updatedAt: .now
        ))

        XCTAssertFalse(coordinator.isActive)
    }
}
