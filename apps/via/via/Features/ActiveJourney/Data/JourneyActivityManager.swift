import ActivityKit
import Foundation

protocol JourneyActivityManaging: Sendable {
    func start(
        attributes: JourneyActivityAttributes,
        state: JourneyActivityAttributes.ContentState,
        staleAt: Date
    ) async
    func update(
        journeyID: JourneyID,
        state: JourneyActivityAttributes.ContentState,
        staleAt: Date,
        alert: JourneyActivityAlert?
    ) async
    func end(
        journeyID: JourneyID,
        finalState: JourneyActivityAttributes.ContentState,
        dismissAt: Date
    ) async
}

final class JourneyActivityManager: JourneyActivityManaging {
    func start(
        attributes: JourneyActivityAttributes,
        state: JourneyActivityAttributes.ContentState,
        staleAt: Date
    ) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        for meetup in Activity<MeetupActivityAttributes>.activities {
            await meetup.end(nil, dismissalPolicy: .immediate)
        }
        if let existing = activity(for: JourneyID(rawValue: attributes.journeyID)) {
            await existing.update(ActivityContent(state: state, staleDate: staleAt))
            return
        }

        do {
            _ = try Activity.request(
                attributes: attributes,
                content: ActivityContent(state: state, staleDate: staleAt),
                pushType: nil
            )
        } catch {
            // Live Activities are additive. A system-level refusal must not
            // prevent the in-app journey from starting.
        }
    }

    func update(
        journeyID: JourneyID,
        state: JourneyActivityAttributes.ContentState,
        staleAt: Date,
        alert: JourneyActivityAlert?
    ) async {
        guard let current = activity(for: journeyID) else { return }
        let alertConfiguration = alert.map {
            AlertConfiguration(
                title: LocalizedStringResource(stringLiteral: $0.title),
                body: LocalizedStringResource(stringLiteral: $0.body),
                sound: .default
            )
        }
        await current.update(
            ActivityContent(state: state, staleDate: staleAt),
            alertConfiguration: alertConfiguration
        )
    }

    func end(
        journeyID: JourneyID,
        finalState: JourneyActivityAttributes.ContentState,
        dismissAt: Date
    ) async {
        guard let current = activity(for: journeyID) else { return }
        let dismissalPolicy: ActivityUIDismissalPolicy = dismissAt <= Date()
            ? .immediate
            : .after(dismissAt)
        await current.end(
            ActivityContent(state: finalState, staleDate: nil),
            dismissalPolicy: dismissalPolicy
        )
    }

    private func activity(for journeyID: JourneyID) -> Activity<JourneyActivityAttributes>? {
        Activity<JourneyActivityAttributes>.activities.first {
            $0.attributes.journeyID == journeyID.rawValue
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
        staleAt: Date,
        alert: JourneyActivityAlert?
    ) async {}

    func end(
        journeyID: JourneyID,
        finalState: JourneyActivityAttributes.ContentState,
        dismissAt: Date
    ) async {}
}
