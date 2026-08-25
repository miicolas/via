import Foundation

/// Effects for starting or saving a journey, kept out of the detail view.
@MainActor
enum JourneyActivation {
    static func plan(
        journey: Journey,
        destination: JourneyDestination,
        source: JourneyResult.Source?,
        planningPolicy: JourneyPlanningPolicy,
        draftModel: PlannedJourneyDraftModel
    ) async -> Bool {
        await draftModel.plan(
            journey: journey,
            destination: destination,
            source: source,
            planningPolicy: planningPolicy
        )
    }

    static func go(
        journey: Journey,
        destination: JourneyDestination,
        source: JourneyResult.Source?,
        planningPolicy: JourneyPlanningPolicy,
        activeJourneyModel: ActiveJourneyModel,
        plannedJourneyDraftModel: PlannedJourneyDraftModel,
        allowsBackgroundTracking: Bool
    ) async {
        if plannedJourneyDraftModel.draft?.journey.id == journey.id {
            await plannedJourneyDraftModel.launch(
                using: activeJourneyModel,
                allowsBackgroundTracking: allowsBackgroundTracking
            )
            return
        }

        await activeJourneyModel.go(
            journey: journey,
            destination: destination,
            source: source,
            planningPolicy: planningPolicy,
            allowsBackgroundTracking: allowsBackgroundTracking
        )
    }
}
