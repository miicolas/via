import SwiftUI

/// The answer half of the natural-language composer: one panel per
/// `NaturalSearchState` that has something to say or to ask, floating above
/// the input field. Restores the state rendering the old `NaturalJourneySheet`
/// carried, adapted to the bottom container the composer lives in now.
struct NaturalJourneyStatePanel: View {
    var viewModel: SearchViewModel

    @State private var contentHeight: CGFloat = 0

    /// The tallest a panel may grow inside the bottom container; anything
    /// longer (place candidates, availability checklists) scrolls within.
    private static let maxPanelHeight: CGFloat = 320

    var body: some View {
        ScrollView {
            content
                .padding(20)
                .onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.size.height
                } action: { height in
                    contentHeight = height
                }
        }
        .frame(height: min(contentHeight, Self.maxPanelHeight))
        .scrollBounceBehavior(.basedOnSize)
        .frame(maxWidth: 560)
        .glassEffect(.regular, in: .rect(cornerRadius: 27))
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.naturalSearchState {
        case .dismissed, .input, .loading:
            // No panel: the field itself carries these states, including the
            // thinking treatment while a request is in flight.
            EmptyView()
        case .onboarding:
            AIOnboardingCard(onTry: viewModel.showNaturalSearchInput)
        case let .clarification(draft, field):
            NaturalJourneyClarificationView(
                draft: draft,
                field: field,
                onResolveTime: { date, meaning in
                    viewModel.resolveNaturalTime(
                        draft: draft,
                        requestedAt: date,
                        represents: meaning,
                    )
                },
                onResolvePlace: { candidate in
                    viewModel.resolveNaturalPlace(
                        draft: draft,
                        field: field,
                        candidate: candidate,
                    )
                },
                onModify: viewModel.modifyNaturalQuery,
            )
        case let .decision(draft, decision):
            NaturalJourneyDecisionView(
                decision: decision,
                onConfirmCurrentLocation: {
                    viewModel.confirmNaturalCurrentLocation(draft: draft)
                },
                onResolveMode: { mode, constraint in
                    viewModel.resolveNaturalModeConflict(
                        draft: draft,
                        mode: mode,
                        keeping: constraint,
                    )
                },
                onContinueWithoutUnsupported: {
                    viewModel.continueNaturalSearchWithoutUnsupportedConstraints(
                        draft: draft,
                    )
                },
                onResolveTimeConflict: { constraint in
                    viewModel.resolveNaturalTimeConflict(
                        draft: draft,
                        keeping: constraint,
                    )
                },
                onModify: viewModel.modifyNaturalQuery,
            )
        case let .unsupported(message, suggestions):
            NaturalJourneyUnsupportedView(
                message: message,
                suggestions: suggestions,
                onModify: viewModel.modifyNaturalQuery,
                onClassicSearch: viewModel.useClassicSearch,
            )
        case let .availability(guidance):
            NaturalJourneyAvailabilityView(
                guidance: guidance,
                onRetry: viewModel.retryNaturalAvailability,
                onClassicSearch: viewModel.useClassicSearch,
            )
        case let .failed(message):
            NaturalJourneyFailureView(
                message: message,
                criteria: viewModel.naturalJourneyCriteria,
                unresolvedDraft: viewModel.naturalJourneyUnresolvedDraft,
                onRetry: viewModel.retryNaturalSearch,
                onClassicSearch: viewModel.useClassicSearch,
            )
        }
    }
}
