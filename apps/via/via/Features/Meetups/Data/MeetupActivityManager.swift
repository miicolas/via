import ActivityKit
import Foundation

protocol MeetupActivityManaging: Sendable {
    func start(
        attributes: MeetupActivityAttributes,
        state: MeetupActivityAttributes.ContentState,
        staleAt: Date
    ) async
    func update(
        meetupID: String,
        state: MeetupActivityAttributes.ContentState,
        staleAt: Date
    ) async
    func end(
        meetupID: String,
        finalState: MeetupActivityAttributes.ContentState,
        dismissAt: Date
    ) async
}

final class MeetupActivityManager: MeetupActivityManaging, @unchecked Sendable {
    private let transport: any MeetupLiveTransport
    /// Resolved on first use rather than in `init`, for the reason
    /// `PushNotificationManager` documents: reading the keychain is a
    /// synchronous XPC round trip and this manager is built during launch.
    private let resolveInstallationID: @Sendable () -> String
    private let environment: APNsEnvironment
    private let lock = NSLock()
    private var tokenTasks: [String: Task<Void, Never>] = [:]

    init(
        transport: any MeetupLiveTransport,
        installationID: @escaping @Sendable () -> String,
        environment: APNsEnvironment
    ) {
        self.transport = transport
        self.resolveInstallationID = installationID
        self.environment = environment
    }

    func start(
        attributes: MeetupActivityAttributes,
        state: MeetupActivityAttributes.ContentState,
        staleAt: Date
    ) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        // The normal journey and rendez-vous activities describe competing
        // active sessions. Only the one the traveller just launched survives.
        for journey in Activity<JourneyActivityAttributes>.activities {
            await journey.end(nil, dismissalPolicy: .immediate)
        }
        for other in Activity<MeetupActivityAttributes>.activities
            where other.attributes.meetupID != attributes.meetupID {
            await stopRegistration(for: other)
            await other.end(nil, dismissalPolicy: .immediate)
        }

        if let existing = activity(for: attributes.meetupID) {
            await existing.update(ActivityContent(state: state, staleDate: staleAt))
            observePushToken(for: existing)
            return
        }

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: ActivityContent(state: state, staleDate: staleAt),
                pushType: .token
            )
            observePushToken(for: activity)
        } catch {
            // The in-app rendez-vous remains usable if activities are disabled,
            // unavailable, or rejected by the system.
        }
    }

    func update(
        meetupID: String,
        state: MeetupActivityAttributes.ContentState,
        staleAt: Date
    ) async {
        guard let current = activity(for: meetupID) else { return }
        await current.update(ActivityContent(state: state, staleDate: staleAt))
    }

    func end(
        meetupID: String,
        finalState: MeetupActivityAttributes.ContentState,
        dismissAt: Date
    ) async {
        guard let current = activity(for: meetupID) else { return }
        let policy: ActivityUIDismissalPolicy = dismissAt <= .now
            ? .immediate
            : .after(dismissAt)
        await current.end(
            ActivityContent(state: finalState, staleDate: nil),
            dismissalPolicy: policy
        )
        await stopRegistration(for: current)
    }

    private func activity(for meetupID: String) -> Activity<MeetupActivityAttributes>? {
        Activity<MeetupActivityAttributes>.activities.first {
            $0.attributes.meetupID == meetupID
        }
    }

    private func observePushToken(for activity: Activity<MeetupActivityAttributes>) {
        let shouldObserve = lock.withLock { tokenTasks[activity.id] == nil }
        guard shouldObserve else { return }
        let handle = SendableMeetupActivity(activity)
        let task = Task { [transport, resolveInstallationID, environment] in
            let installationID = resolveInstallationID()
            for await tokenData in handle.value.pushTokenUpdates {
                guard !Task.isCancelled else { return }
                let token = PushNotificationManager.hexToken(tokenData)
                try? await transport.registerActivity(
                    meetupId: handle.value.attributes.meetupID,
                    installationId: installationID,
                    activityId: handle.value.id,
                    token: token,
                    environment: environment
                )
            }
        }
        lock.withLock { tokenTasks[activity.id] = task }
    }

    private func stopRegistration(for activity: Activity<MeetupActivityAttributes>) async {
        lock.withLock { tokenTasks.removeValue(forKey: activity.id) }?.cancel()
        try? await transport.unregisterActivity(
            meetupId: activity.attributes.meetupID,
            installationId: resolveInstallationID(),
            activityId: activity.id
        )
    }
}

/// ActivityKit owns the synchronization of an Activity instance. Swift 6 does
/// not currently annotate that reference as Sendable even though its async
/// token sequence is specifically designed to be consumed from a task.
private struct SendableMeetupActivity: @unchecked Sendable {
    let value: Activity<MeetupActivityAttributes>

    init(_ value: Activity<MeetupActivityAttributes>) {
        self.value = value
    }
}

struct NoOpMeetupActivityManager: MeetupActivityManaging {
    func start(
        attributes: MeetupActivityAttributes,
        state: MeetupActivityAttributes.ContentState,
        staleAt: Date
    ) async {}

    func update(
        meetupID: String,
        state: MeetupActivityAttributes.ContentState,
        staleAt: Date
    ) async {}

    func end(
        meetupID: String,
        finalState: MeetupActivityAttributes.ContentState,
        dismissAt: Date
    ) async {}
}
