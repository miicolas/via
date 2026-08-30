import Foundation
import Observation

/// The one place that assembles a `JourneyContext` from the four providers a
/// journey can arrive through — the live session, a scheduled reminder, a
/// planned draft, and the current search.
///
/// The shell asks for the context of its current surface; a journey sheet asks
/// for one journey by id. Both go through `JourneyContextResolver`, so the
/// precedence rule and the candidate construction live exactly once.
@MainActor
@Observable
final class JourneyContextSource {
    /// Which trajet surface the shell is presenting. Search results only count
    /// while a search surface is visible; the planned and scheduled providers
    /// only count for their dedicated sheet.
    enum Surface: Hashable {
        case hidden
        case search
        case sheet(SearchSheetDestination)
    }

    private let searchViewModel: SearchViewModel
    private let plannedJourneyDraftModel: PlannedJourneyDraftModel
    private let journeyNotificationCoordinator: JourneyNotificationCoordinator
    private let activeJourneyModel: ActiveJourneyModel

    init(
        searchViewModel: SearchViewModel,
        plannedJourneyDraftModel: PlannedJourneyDraftModel,
        journeyNotificationCoordinator: JourneyNotificationCoordinator,
        activeJourneyModel: ActiveJourneyModel
    ) {
        self.searchViewModel = searchViewModel
        self.plannedJourneyDraftModel = plannedJourneyDraftModel
        self.journeyNotificationCoordinator = journeyNotificationCoordinator
        self.activeJourneyModel = activeJourneyModel
    }

    /// The context the map should draw for the shell's current surface.
    func current(for surface: Surface) -> JourneyContext? {
        let search = surface != .hidden
            ? searchContext(for: searchViewModel.selectedJourneyID)
            : nil
        let planned: JourneyContext? = if case .sheet(.plannedJourney) = surface {
            plannedContext
        } else {
            nil
        }
        let reminder: JourneyContext? = if case .sheet(.scheduledJourney(let journeyID)) = surface {
            reminderContext(for: journeyID)
        } else {
            nil
        }

        let journeyID = searchViewModel.selectedJourneyID
            ?? activeJourneyModel.journey?.id
            ?? activeJourneyModel.arrival?.journeyID
            ?? planned?.journey.id
            ?? reminder?.journey.id

        guard let journeyID else { return nil }
        return JourneyContextResolver.resolve(
            journeyID: journeyID,
            active: activeContext,
            reminder: reminder,
            planned: planned,
            search: search
        )
    }

    /// The route section the map should emphasise for the shell's surface.
    func highlightedSectionID(for surface: Surface) -> String? {
        activeJourneyModel.highlightedSectionID
            ?? (surface != .hidden ? searchViewModel.highlightedJourneySectionID : nil)
    }

    /// One journey's context, as a dedicated journey sheet resolves it: the
    /// live session first, so a restored journey resolves even when the search
    /// result set is empty; otherwise the journey is looked up in the current
    /// proposal.
    func context(
        for journeyID: JourneyID,
        isPlanned: Bool,
        isScheduled: Bool
    ) -> JourneyContext? {
        JourneyContextResolver.resolve(
            journeyID: journeyID,
            active: activeContext,
            reminder: isScheduled ? reminderContext(for: journeyID) : nil,
            planned: isPlanned ? plannedContext : nil,
            search: searchContext(for: journeyID)
        )
    }

    // MARK: - Candidates

    private var activeContext: JourneyContext? {
        activeJourneyModel.session.map {
            JourneyContext(
                journey: $0.journey,
                destination: $0.destination,
                source: $0.source,
                planningPolicy: $0.planningPolicy
            )
        }
    }

    private var plannedContext: JourneyContext? {
        plannedJourneyDraftModel.draft.map {
            JourneyContext(
                journey: $0.journey,
                destination: $0.destination,
                source: $0.source,
                planningPolicy: $0.planningPolicy
            )
        }
    }

    private func reminderContext(for journeyID: JourneyID) -> JourneyContext? {
        journeyNotificationCoordinator.reminder(for: journeyID).map {
            JourneyContext(
                journey: $0.journey,
                destination: $0.destination,
                source: $0.source,
                planningPolicy: $0.planningPolicy
            )
        }
    }

    private func searchContext(for journeyID: JourneyID?) -> JourneyContext? {
        guard let journeyID,
              let journey = searchViewModel.journeyResult?.journeys
                  .first(where: { $0.id == journeyID }),
              let destination = searchViewModel.journeyDestination
        else { return nil }
        return JourneyContext(
            journey: journey,
            destination: destination,
            source: searchViewModel.journeyResult?.source,
            planningPolicy: searchViewModel.journeyPlanningPolicy
        )
    }
}
