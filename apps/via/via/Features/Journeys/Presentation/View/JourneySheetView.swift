import SwiftUI

/// Journey sheet stacked above the tab sheet, mirroring the station detail
/// sheet. It hosts the itinerary detail as the stack root and pushes the
/// running-guidance / arrival panel within the same NavigationStack, so the
/// whole trajet lives at a single presentation level.
struct JourneySheetView: View {
    let journeyID: JourneyID
    let searchViewModel: SearchViewModel
    let activeJourneyModel: ActiveJourneyModel
    let journeyNotificationCoordinator: JourneyNotificationCoordinator
    let scheduledReminder: ScheduledJourneyReminder?
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

    init(
        journeyID: JourneyID,
        searchViewModel: SearchViewModel,
        activeJourneyModel: ActiveJourneyModel,
        journeyNotificationCoordinator: JourneyNotificationCoordinator = .preview,
        scheduledReminder: ScheduledJourneyReminder? = nil,
        isLargeScreen: Bool,
        detent: Binding<PresentationDetent>,
        onExpandMap: @escaping () -> Void,
        onOpenReport: @escaping () -> Void
    ) {
        self.journeyID = journeyID
        self.searchViewModel = searchViewModel
        self.activeJourneyModel = activeJourneyModel
        self.journeyNotificationCoordinator = journeyNotificationCoordinator
        self.scheduledReminder = scheduledReminder
        self.isLargeScreen = isLargeScreen
        _detent = detent
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
                        journeyNotificationCoordinator: journeyNotificationCoordinator,
                        prefersGoAction: scheduledReminder != nil,
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
        // At the peek the guidance panel has no room for its navigation bar and
        // its pinned header at once: they overlap and spill over the map. The
        // compact strip says the same thing in the height there is.
        .opacity(showsCompactGuidance ? 0 : 1)
        .accessibilityHidden(showsCompactGuidance)
        .overlay(alignment: .top) { compactGuidance }
        .onHeightChange(for: Self.isAtPeek(sheetHeight:)) { isAtPeek = $0 }
        .detailSheetPresentation(
            isLargeScreen: isLargeScreen,
            collapsedHeight: JourneySheetDetents.peekHeight(isGuiding: activeJourneyModel.isGuiding),
            selection: $detent
        )
    }

    /// Sits above the (hidden) guidance panel rather than replacing it, so the
    /// pushed stack keeps its scroll position while the sheet is put away.
    @ViewBuilder
    private var compactGuidance: some View {
        if showsCompactGuidance {
            ActiveJourneyCompactStrip(model: activeJourneyModel) {
                detent = DetailSheetPresentation.expanded(isLargeScreen: isLargeScreen)
            }
            // Clears the drag indicator the sheet draws at its top edge.
            .padding(.top, 16)
            .transition(.opacity)
        }
    }

    /// Whether the sheet sits low enough for the strip to take over. Kept free
    /// of the eligibility question so the measurement reduces to a Bool that
    /// changes twice per drag instead of a height that changes every frame.
    private static func isAtPeek(sheetHeight: CGFloat) -> Bool {
        guard sheetHeight > 0 else { return false }
        return SheetTabPresentation.showsCompactContent(
            isEligible: true,
            measuredContentProgress: SheetTabDetents.contentProgress(
                sheetHeight: sheetHeight,
                hasCompactContent: true
            )
        )
    }

    private var showsCompactGuidance: Bool {
        activeJourneyModel.isGuiding && isAtPeek == true
    }

    /// Prefers the live session so a restored journey resolves even when the
    /// search result set is empty; otherwise looks the journey up in the
    /// current proposal.
    private var resolvedJourney: (journey: Journey, destination: JourneyDestination, source: JourneyResult.Source?)? {
        if let scheduledReminder, scheduledReminder.journey.id == journeyID {
            return (
                scheduledReminder.journey,
                scheduledReminder.destination,
                scheduledReminder.source
            )
        }
        if let session = activeJourneyModel.session, session.journey.id == journeyID {
            return (session.journey, session.destination, session.source)
        }
        if let journey = searchViewModel.journeyResult?.journeys.first(where: { $0.id == journeyID }),
           let destination = searchViewModel.journeyDestination {
            return (journey, destination, searchViewModel.journeyResult?.source)
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
                onOpenReport: onOpenReport,
            )
        }
    }
}
