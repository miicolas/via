import ActivityKit
import Foundation

protocol JourneyActivityPushTokenSink: Sendable {
    func registerActivityPushToken(
        _ token: Data,
        activityID: String,
        journeyID: String
    ) async
    func unregisterActivityPushToken(activityID: String) async
    func registerPushToStartToken(_ token: Data) async
}

struct NoOpJourneyActivityPushTokenSink: JourneyActivityPushTokenSink {
    func registerActivityPushToken(
        _ token: Data,
        activityID: String,
        journeyID: String
    ) async {}

    func unregisterActivityPushToken(activityID: String) async {}
    func registerPushToStartToken(_ token: Data) async {}
}

protocol JourneyActivityManaging: Sendable {
    func start(
        attributes: JourneyActivityAttributes,
        state: JourneyActivityAttributes.ContentState,
        staleAt: Date
    ) async
    func update(
        journeyID: JourneyID,
        state: JourneyActivityAttributes.ContentState,
        staleAt: Date
    ) async
    func end(
        journeyID: JourneyID,
        finalState: JourneyActivityAttributes.ContentState,
        dismissAt: Date
    ) async
}

@MainActor
final class JourneyActivityManager: JourneyActivityManaging {
    private let tokenSink: any JourneyActivityPushTokenSink
    private var activityUpdatesTask: Task<Void, Never>?
    private var tokenTasks: [String: Task<Void, Never>] = [:]
    private var stateTasks: [String: Task<Void, Never>] = [:]
    private var pushToStartTask: Task<Void, Never>?

    init(tokenSink: any JourneyActivityPushTokenSink = NoOpJourneyActivityPushTokenSink()) {
        self.tokenSink = tokenSink
        activityUpdatesTask = Task { [weak self] in
            for await activity in Activity<JourneyActivityAttributes>.activityUpdates {
                guard let self else { return }
                observePushTokenUpdates(for: activity)
            }
        }
        pushToStartTask = Task { [tokenSink] in
            for await token in Activity<JourneyActivityAttributes>.pushToStartTokenUpdates {
                await tokenSink.registerPushToStartToken(token)
            }
        }
        for activity in Activity<JourneyActivityAttributes>.activities {
            observePushTokenUpdates(for: activity)
        }
    }

    deinit {
        activityUpdatesTask?.cancel()
        pushToStartTask?.cancel()
        tokenTasks.values.forEach { $0.cancel() }
        stateTasks.values.forEach { $0.cancel() }
    }

    func start(
        attributes: JourneyActivityAttributes,
        state: JourneyActivityAttributes.ContentState,
        staleAt: Date
    ) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        if let existing = activity(for: JourneyID(rawValue: attributes.journeyID)) {
            observePushTokenUpdates(for: existing)
            await existing.update(ActivityContent(state: state, staleDate: staleAt))
            return
        }

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: ActivityContent(state: state, staleDate: staleAt),
                pushType: .token
            )
            observePushTokenUpdates(for: activity)
        } catch {
            // Live Activities are additive. A system-level refusal must not
            // prevent the in-app journey from starting.
        }
    }

    func update(
        journeyID: JourneyID,
        state: JourneyActivityAttributes.ContentState,
        staleAt: Date
    ) async {
        guard let current = activity(for: journeyID) else { return }
        await current.update(ActivityContent(state: state, staleDate: staleAt))
    }

    func end(
        journeyID: JourneyID,
        finalState: JourneyActivityAttributes.ContentState,
        dismissAt: Date
    ) async {
        guard let current = activity(for: journeyID) else { return }
        await current.end(
            ActivityContent(state: finalState, staleDate: nil),
            dismissalPolicy: .after(dismissAt)
        )
        tokenTasks.removeValue(forKey: current.id)?.cancel()
        stateTasks.removeValue(forKey: current.id)?.cancel()
        await tokenSink.unregisterActivityPushToken(activityID: current.id)
    }

    private func activity(for journeyID: JourneyID) -> Activity<JourneyActivityAttributes>? {
        Activity<JourneyActivityAttributes>.activities.first {
            $0.attributes.journeyID == journeyID.rawValue
        }
    }

    private func observePushTokenUpdates(for activity: Activity<JourneyActivityAttributes>) {
        guard tokenTasks[activity.id] == nil else { return }
        let tokenSink = self.tokenSink
        tokenTasks[activity.id] = Task { [tokenSink, activity] in
            for await token in activity.pushTokenUpdates {
                await tokenSink.registerActivityPushToken(
                    token,
                    activityID: activity.id,
                    journeyID: activity.attributes.journeyID
                )
            }
        }
        observeActivityStateUpdates(for: activity)
    }

    private func observeActivityStateUpdates(for activity: Activity<JourneyActivityAttributes>) {
        guard stateTasks[activity.id] == nil else { return }
        let tokenSink = self.tokenSink
        stateTasks[activity.id] = Task { [tokenSink, activity] in
            for await state in activity.activityStateUpdates {
                switch state {
                case .ended, .dismissed:
                    await tokenSink.unregisterActivityPushToken(activityID: activity.id)
                    return
                default:
                    continue
                }
            }
        }
    }
}

struct NoOpJourneyActivityManager: JourneyActivityManaging {
    func start(
        attributes: JourneyActivityAttributes,
        state: JourneyActivityAttributes.ContentState,
        staleAt: Date
    ) async {}

    func update(
        journeyID: JourneyID,
        state: JourneyActivityAttributes.ContentState,
        staleAt: Date
    ) async {}

    func end(
        journeyID: JourneyID,
        finalState: JourneyActivityAttributes.ContentState,
        dismissAt: Date
    ) async {}
}
