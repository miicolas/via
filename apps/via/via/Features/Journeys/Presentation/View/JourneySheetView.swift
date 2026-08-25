import SwiftUI

/// Journey sheet stacked above the tab sheet, mirroring the station detail
/// sheet. It hosts the itinerary detail as the stack root and pushes the
/// running-guidance / arrival panel within the same NavigationStack, so the
/// whole trajet lives at a single presentation level.
struct JourneySheetView: View {
    let journeyID: JourneyID
    let searchViewModel: SearchViewModel
    let activeJourneyModel: ActiveJourneyModel
    let plannedJourneyDraftModel: PlannedJourneyDraftModel
    let journeyNotificationCoordinator: JourneyNotificationCoordinator
    let departureChoicesRepository: any JourneyDepartureChoicesRepository
    let scheduledReminder: ScheduledJourneyReminder?
    let isPlannedJourney: Bool
    var isLargeScreen: Bool
    @Binding var detent: PresentationDetent
    let onExpandMap: () -> Void
    let onOpenReport: () -> Void

    /// Measured rather than read off `detent`: the selection only settles when
    /// the drag ends, so the guidance panel would stay hidden all the way up.
    /// Stored already reduced to the answer, and `nil` until the first
    /// measurement — a zero height would read as the peek and flash the strip
    /// over a full-height sheet on the first frame.
    @State private var isAtPeek: Bool?
    @State private var departureChoicesModel: JourneyDepartureChoicesModel

    @Environment(\.scenePhase) private var scenePhase

    init(
        journeyID: JourneyID,
        searchViewModel: SearchViewModel,
        activeJourneyModel: ActiveJourneyModel,
        plannedJourneyDraftModel: PlannedJourneyDraftModel,
        journeyNotificationCoordinator: JourneyNotificationCoordinator = .preview,
        departureChoicesRepository: any JourneyDepartureChoicesRepository = InMemoryJourneyDepartureChoicesRepository.unavailable,
        scheduledReminder: ScheduledJourneyReminder? = nil,
        isPlannedJourney: Bool = false,
        isLargeScreen: Bool,
        detent: Binding<PresentationDetent>,
        onExpandMap: @escaping () -> Void,
        onOpenReport: @escaping () -> Void
    ) {
        self.journeyID = journeyID
        self.searchViewModel = searchViewModel
        self.activeJourneyModel = activeJourneyModel
        self.plannedJourneyDraftModel = plannedJourneyDraftModel
        self.journeyNotificationCoordinator = journeyNotificationCoordinator
        self.departureChoicesRepository = departureChoicesRepository
        self.scheduledReminder = scheduledReminder
        self.isPlannedJourney = isPlannedJourney
        self.isLargeScreen = isLargeScreen
        _detent = detent
        _departureChoicesModel = State(
            initialValue: JourneyDepartureChoicesModel(repository: departureChoicesRepository)
        )
        self.onExpandMap = onExpandMap
        self.onOpenReport = onOpenReport
    }

    var body: some View {
        NavigationStack {
            Group {
                if let resolved = resolvedJourney {
                    JourneyDetailView(
                        journey: resolved.journey,
                        destination: resolved.destination,
                        source: resolved.source,
                        activeJourneyModel: activeJourneyModel,
                        plannedJourneyDraftModel: plannedJourneyDraftModel,
                        journeyNotificationCoordinator: journeyNotificationCoordinator,
                        planningPolicy: resolved.policy,
                        departureChoicesModel: departureChoicesModel,
                        onSelectDeparture: selectDeparture,
                        onRetryDepartures: refreshDepartureChoices,
                        onUpdateTime: updateTime,
                        prefersGoAction: !shouldPlanOpenedJourney,
                        prefersPlanAction: shouldPlanOpenedJourney,
                        isCompact: showsCompactJourney,
                        onHighlightSection: searchViewModel.highlightJourneySection,
                        onExpandMap: onExpandMap,
                    )
                    .navigationDestination(isPresented: guidanceBinding) {
                        guidanceDestination
                    }
                } else {
                    // No detail to resolve (e.g. an arrival that outlived its
                    // journey result): show the active surface directly.
                    guidanceDestination
                }
            }
        }
        // At the peek the full detail has no room for its navigation bar, route
        // timeline and action bar at once. A compact summary keeps the useful
        // journey facts visible while the map remains the dominant context.
        .opacity(showsCompactGuidance ? 0 : 1)
        .accessibilityHidden(showsCompactGuidance)
        .overlay(alignment: .top) { compactContent }
        .onHeightChange(for: isAtPeek(sheetHeight:)) { isAtPeek = $0 }
        .detailSheetPresentation(
            isLargeScreen: isLargeScreen,
            collapsedHeight: JourneySheetDetents.peekHeight(isGuiding: activeJourneyModel.isGuiding),
            selection: $detent
        )
        .task(id: scenePhase) {
            guard scenePhase == .active, let resolved = resolvedJourney else { return }
            await departureChoicesModel.runAutomaticRefresh(
                journey: { resolvedJourney?.journey ?? resolved.journey },
                destination: resolved.destination,
                policy: resolved.policy,
                apply: applyRevision
            )
        }
        .onChange(of: journeyID) { _, _ in departureChoicesModel.reset() }
    }

    /// Sits above the (hidden) detail content rather than replacing it, so the
    /// pushed stack keeps its scroll position while the sheet is put away.
    private var compactContent: some View {
        Group {
            if showsCompactGuidance {
                ActiveJourneyCompactStrip(model: activeJourneyModel) {
                    detent = DetailSheetPresentation.expanded(isLargeScreen: isLargeScreen)
                }
            } else if showsCompactJourney, let resolvedJourney {
                JourneyCompactSummaryView(
                    journey: resolvedJourney.journey,
                    source: resolvedJourney.source
                ) {
                    detent = DetailSheetPresentation.expanded(isLargeScreen: isLargeScreen)
                }
            }
        }
        // Clears the drag indicator the sheet draws at its top edge.
        .padding(.top, 16)
        .transition(.opacity)
    }

    /// Whether the sheet sits at its collapsed detent. A detail peek has its
    /// own height, while the running journey keeps the tab sheet's measured
    /// progress contract because its compact strip is shorter.
    private func isAtPeek(sheetHeight: CGFloat) -> Bool {
        guard sheetHeight > 0 else { return false }
        if activeJourneyModel.isGuiding {
            return SheetTabPresentation.showsCompactContent(
                isEligible: true,
                measuredContentProgress: SheetTabDetents.contentProgress(
                    sheetHeight: sheetHeight,
                    hasCompactContent: true
                )
            )
        }
        return sheetHeight <= JourneySheetDetents.detailPeekHeight + 1
    }

    private var showsCompactGuidance: Bool {
        activeJourneyModel.isGuiding && isAtPeek == true
    }

    private var showsCompactJourney: Bool {
        !activeJourneyModel.isGuiding && isAtPeek == true && resolvedJourney != nil
    }

    /// The action follows the search intent, not the headway of the first
    /// result. A "now" search can legitimately start a journey whose service
    /// leaves in twenty minutes; only a deliberately future time is a saved
    /// plan.
    private var shouldPlanOpenedJourney: Bool {
        guard scheduledReminder == nil, !isPlannedJourney else { return false }
        return ActiveJourneyRules.isFutureJourneyRequest(
            requestedAt: searchViewModel.journeyRequestedAt,
            at: .now
        )
    }

    /// Prefers the live session so a restored journey resolves even when the
    /// search result set is empty; otherwise looks the journey up in the
    /// current proposal.
    private var resolvedJourney: (
        journey: Journey,
        destination: JourneyDestination,
        source: JourneyResult.Source?,
        policy: JourneyPlanningPolicy
    )? {
        if let session = activeJourneyModel.session, session.journey.id == journeyID {
            return (session.journey, session.destination, session.source, session.planningPolicy)
        }
        if scheduledReminder != nil,
           let scheduledReminder = journeyNotificationCoordinator.reminder(for: journeyID) {
            return (
                scheduledReminder.journey,
                scheduledReminder.destination,
                scheduledReminder.source,
                scheduledReminder.planningPolicy
            )
        }
        if isPlannedJourney,
           let draft = plannedJourneyDraftModel.draft,
           draft.journey.id == journeyID {
            return (draft.journey, draft.destination, draft.source, draft.planningPolicy)
        }
        if let journey = searchViewModel.journeyResult?.journeys.first(where: { $0.id == journeyID }),
           let destination = searchViewModel.journeyDestination {
            return (
                journey,
                destination,
                searchViewModel.journeyResult?.source,
                searchViewModel.journeyPlanningPolicy
            )
        }
        return nil
    }

    /// Dismissal is driven by the model, matching the previous in-tab guidance:
    /// the push follows the running session and clears itself when it ends.
    private var guidanceBinding: Binding<Bool> {
        Binding(
            get: { activeJourneyModel.hasSurface },
            set: { _ in },
        )
    }

    @ViewBuilder
    private var guidanceDestination: some View {
        if let arrival = activeJourneyModel.arrival {
            JourneyArrivalView(
                arrival: arrival,
                onComplete: activeJourneyModel.completeArrival,
            )
        } else if activeJourneyModel.isActive {
            ActiveJourneyPanelView(
                model: activeJourneyModel,
                departureChoicesModel: departureChoicesModel,
                onSelectDeparture: selectDeparture,
                onRetryDepartures: refreshDepartureChoices,
            )
        }
    }

    private func refreshDepartureChoices() async {
        guard let resolved = resolvedJourney else { return }
        await departureChoicesModel.refresh(
            journey: resolved.journey,
            destination: resolved.destination,
            policy: resolved.policy,
            apply: applyRevision
        )
    }

    private func selectDeparture(
        _ choice: JourneyDepartureChoice,
        sectionID: String
    ) {
        guard let resolved = resolvedJourney else { return }
        Task {
            await departureChoicesModel.select(
                choice,
                in: sectionID,
                journey: resolved.journey,
                destination: resolved.destination,
                policy: resolved.policy,
                apply: applyRevision
            )
        }
    }

    private func applyRevision(_ journey: Journey) async {
        if activeJourneyModel.session?.journey.id == journey.id {
            await activeJourneyModel.applyDepartureRevision(journey)
        } else if plannedJourneyDraftModel.draft?.journey.id == journey.id {
            await plannedJourneyDraftModel.applyJourneyRevision(journey)
        } else {
            searchViewModel.replaceJourney(journey)
            await journeyNotificationCoordinator.applyJourneyRevision(journey)
        }
    }

    private func updateTime(
        _ requestedAt: Date,
        represents: JourneyDatetimeRepresents
    ) async throws {
        guard let resolved = resolvedJourney else {
            throw JourneyScheduleRevisionError.unavailable
        }
        let revision = try await searchViewModel.reviseJourneySchedule(
            resolved.journey,
            destination: resolved.destination,
            policy: resolved.policy,
            requestedAt: requestedAt,
            represents: represents
        )
        departureChoicesModel.reset()
        searchViewModel.highlightJourneySection(nil)
        await applyRevision(revision)
    }
}
