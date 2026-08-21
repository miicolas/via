import SwiftUI

/// Journey sheet stacked above the tab sheet, mirroring the station detail
/// sheet. It hosts the itinerary detail as the stack root and pushes the
/// running-guidance / arrival panel within the same NavigationStack, so the
/// whole trajet lives at a single presentation level.
struct JourneySheetView: View {
    let journeyID: JourneyID
    let searchViewModel: SearchViewModel
    let activeJourneyModel: ActiveJourneyModel
    var isLargeScreen: Bool
    @Binding var detent: PresentationDetent
    let onExpandMap: () -> Void
    let onOpenReport: () -> Void

    var body: some View {
        NavigationStack {
            Group {
                if let resolved = resolvedJourney {
                    JourneyDetailView(
                        journey: resolved.journey,
                        destination: resolved.destination,
                        source: resolved.source,
                        activeJourneyModel: activeJourneyModel,
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
        .detailSheetPresentation(isLargeScreen: isLargeScreen, selection: $detent)
    }

    /// Prefers the live session so a restored journey resolves even when the
    /// search result set is empty; otherwise looks the journey up in the
    /// current proposal.
    private var resolvedJourney: (journey: Journey, destination: JourneyDestination, source: JourneyResult.Source?)? {
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
            get: { activeJourneyModel.isActive || activeJourneyModel.arrival != nil },
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
