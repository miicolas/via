import Foundation

/// What `MeetupsModel` and the rendez-vous screens see of the live session,
/// mirroring how `ActiveJourneyModel` depends on `JourneyActivityManaging`
/// instead of the concrete Live Activity stack. `MeetupLiveCoordinator` is
/// the production conformance.
@MainActor
protocol MeetupLiveSharing: AnyObject {
    var activeMeetup: Meetup? { get }
    var snapshot: MeetupLiveSnapshot? { get }
    var preciseLocations: [String: MeetupPreciseLocation] { get }
    var isActive: Bool { get }
    func start(_ meetup: Meetup, includesLiveActivity: Bool) async
    func updateProgress(_ next: MeetupProgress) async
    func applyShareLevelChange(_ meetup: Meetup) async
    func stop(publishing status: MeetupProgressStatus?) async
    func observeWhileVisible(meetupId: String) async
}

extension MeetupLiveSharing {
    var isActive: Bool { activeMeetup != nil }

    func stop() async { await stop(publishing: .stopped) }
}

/// Inert conformance for previews and tests that never go live.
@MainActor
final class NoOpMeetupLiveSharing: MeetupLiveSharing {
    var activeMeetup: Meetup? { nil }
    var snapshot: MeetupLiveSnapshot? { nil }
    var preciseLocations: [String: MeetupPreciseLocation] { [:] }
    func start(_ meetup: Meetup, includesLiveActivity: Bool) async {}
    func updateProgress(_ next: MeetupProgress) async {}
    func applyShareLevelChange(_ meetup: Meetup) async {}
    func stop(publishing status: MeetupProgressStatus?) async {}
    func observeWhileVisible(meetupId: String) async {}
}
