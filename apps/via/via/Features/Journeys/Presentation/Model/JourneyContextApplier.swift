import Foundation

/// Applies a revised journey to the surface that owns it.
///
/// The caller only needs to provide the four existing owners. The identity
/// check keeps a stale departure-choice response from mutating another
/// journey that happens to be visible later.
@MainActor
struct JourneyContextApplier {
    let activeJourneyModel: ActiveJourneyModel
    let plannedJourneyDraftModel: PlannedJourneyDraftModel
    let searchViewModel: SearchViewModel
    let journeyNotificationCoordinator: JourneyNotificationCoordinator

    func apply(_ journey: Journey) async {
        if activeJourneyModel.session?.journey.id == journey.id {
            await activeJourneyModel.applyDepartureRevision(journey)
        } else if plannedJourneyDraftModel.draft?.journey.id == journey.id {
            await plannedJourneyDraftModel.applyJourneyRevision(journey)
        } else {
            searchViewModel.replaceJourney(journey)
            await journeyNotificationCoordinator.applyJourneyRevision(journey)
        }
    }
}
