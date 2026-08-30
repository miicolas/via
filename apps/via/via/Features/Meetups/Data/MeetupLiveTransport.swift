import Foundation

/// The Partage-live wire surface. This is everything `MeetupLiveCoordinator`
/// and `MeetupActivityManager` need from the backend, and nothing the
/// rendez-vous screens call. `LiveMeetupRepository` and
/// `InMemoryMeetupRepository` conform alongside `MeetupRepository`.
protocol MeetupLiveTransport: Sendable {
    func publish(
        meetupId: String,
        progress: MeetupProgress?,
        presence: MeetupEncryptedPresence?
    ) async throws -> Int
    func poll(meetupId: String, sinceRevision: Int) async throws -> MeetupLiveSnapshot
    func registerActivity(
        meetupId: String,
        installationId: String,
        activityId: String,
        token: String,
        environment: APNsEnvironment
    ) async throws
    func unregisterActivity(
        meetupId: String,
        installationId: String,
        activityId: String
    ) async throws
    func synchronizeGroupKey(for meetup: Meetup) async throws
}
