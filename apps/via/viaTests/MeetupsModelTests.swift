import XCTest
@testable import Via

@MainActor
final class MeetupsModelTests: XCTestCase {
    func testMutationRefreshesSelectedMeetupAndList() async {
        let meetup = makeMeetup()
        let (model, _) = makeModel(repository: InMemoryMeetupRepository(meetups: [meetup]))
        await model.load()
        await model.select(meetup)

        await model.setZone(.front)

        XCTAssertEqual(model.selectedMeetup?.currentParticipant?.zone, .front)
        XCTAssertEqual(model.meetups.first?.currentParticipant?.zone, .front)
        XCTAssertNil(model.errorMessage)
    }

    func testMutationFailureSurfacesErrorMessage() async {
        let meetup = makeMeetup()
        let (model, _) = makeModel(
            repository: InMemoryMeetupRepository(meetups: [meetup], failure: .unauthorized)
        )
        await model.load()
        await model.select(meetup)

        await model.setShareLevel(.off)

        XCTAssertEqual(model.errorMessage, "Cette action n’est pas autorisée.")
        XCTAssertEqual(model.selectedMeetup?.currentParticipant?.shareLevel, .progressOnly)
    }

    func testShareLevelChangeNotifiesLiveSharing() async {
        let meetup = makeMeetup()
        let (model, live) = makeModel(repository: InMemoryMeetupRepository(meetups: [meetup]))
        await model.load()
        await model.select(meetup)

        await model.setShareLevel(.off)

        XCTAssertEqual(live.shareLevelChanges.count, 1)
        XCTAssertEqual(live.shareLevelChanges.first?.currentParticipant?.shareLevel, .off)
    }

    func testZoneChangeDoesNotNotifyLiveSharing() async {
        let meetup = makeMeetup()
        let (model, live) = makeModel(repository: InMemoryMeetupRepository(meetups: [meetup]))
        await model.load()
        await model.select(meetup)

        await model.setZone(.rear)

        XCTAssertTrue(live.shareLevelChanges.isEmpty)
        XCTAssertEqual(model.selectedMeetup?.currentParticipant?.zone, .rear)
    }

    func testFailedShareLevelChangeDoesNotNotifyLiveSharing() async {
        let meetup = makeMeetup()
        let (model, live) = makeModel(
            repository: InMemoryMeetupRepository(meetups: [meetup], failure: .transport)
        )
        await model.load()
        await model.select(meetup)

        await model.setShareLevel(.off)

        XCTAssertTrue(live.shareLevelChanges.isEmpty)
        XCTAssertEqual(model.errorMessage, "Rendez-vous est momentanément indisponible.")
    }

    func testLeaveStopsActiveSharingAndClearsSelection() async {
        let meetup = makeMeetup()
        let (model, live) = makeModel(repository: InMemoryMeetupRepository(meetups: [meetup]))
        await model.load()
        await model.select(meetup)
        live.activeMeetup = meetup

        let left = await model.leave()

        XCTAssertTrue(left)
        XCTAssertNil(model.selectedMeetup)
        XCTAssertTrue(model.meetups.isEmpty)
        XCTAssertEqual(live.stops, [nil])
    }

    func testCancelStopsActiveSharingAndMarksMeetupCancelled() async {
        let meetup = makeMeetup()
        let (model, live) = makeModel(repository: InMemoryMeetupRepository(meetups: [meetup]))
        await model.load()
        await model.select(meetup)
        live.activeMeetup = meetup

        let cancelled = await model.cancel()

        XCTAssertTrue(cancelled)
        XCTAssertEqual(model.selectedMeetup?.phase, .cancelled)
        XCTAssertEqual(model.meetups.first?.phase, .cancelled)
        XCTAssertEqual(live.stops, [nil])
    }

    func testLeaveDoesNotStopSharingForAnotherMeetup() async {
        let meetup = makeMeetup()
        let (model, live) = makeModel(repository: InMemoryMeetupRepository(meetups: [meetup]))
        await model.load()
        await model.select(meetup)
        live.activeMeetup = makeMeetup(id: "another-meetup")

        _ = await model.leave()

        XCTAssertTrue(live.stops.isEmpty)
    }

    private func makeModel(
        repository: InMemoryMeetupRepository
    ) -> (MeetupsModel, RecordingMeetupLiveSharing) {
        let live = RecordingMeetupLiveSharing()
        let model = MeetupsModel(
            repository: repository,
            searchRepository: InMemorySearchRepository.preview,
            locationModel: LocationModel(adapter: InMemoryLocationAdapter()),
            live: live
        )
        return (model, live)
    }

    private func makeMeetup(id: String = "meetup") -> Meetup {
        let now = Date(timeIntervalSince1970: 1_755_000_000)
        let participant = MeetupParticipant(
            id: "participant",
            displayName: "Alice",
            role: .organizer,
            state: .ready,
            shareLevel: .progressOnly,
            zone: .middle,
            firstBoardingStation: nil,
            departureAt: now,
            arrivalAt: now.addingTimeInterval(1_800),
            createdAt: now,
            updatedAt: now
        )
        return Meetup(
            id: id,
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
    }
}

/// Records what `MeetupsModel` asks of the live seam without dragging in the
/// location, crypto, or Live Activity stacks.
@MainActor
private final class RecordingMeetupLiveSharing: MeetupLiveSharing {
    var activeMeetup: Meetup?
    var snapshot: MeetupLiveSnapshot?
    var preciseLocations: [String: MeetupPreciseLocation] = [:]
    private(set) var started: [Meetup] = []
    private(set) var shareLevelChanges: [Meetup] = []
    private(set) var stops: [MeetupProgressStatus?] = []

    func start(_ meetup: Meetup, includesLiveActivity: Bool) async {
        started.append(meetup)
        activeMeetup = meetup
    }

    func updateProgress(_ next: MeetupProgress) async {}

    func applyShareLevelChange(_ meetup: Meetup) async {
        shareLevelChanges.append(meetup)
    }

    func stop(publishing status: MeetupProgressStatus?) async {
        stops.append(status)
        activeMeetup = nil
    }

    func observeWhileVisible(meetupId: String) async {}
}
