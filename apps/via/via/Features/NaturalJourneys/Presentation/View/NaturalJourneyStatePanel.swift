import SwiftUI

/// The answer half of the natural-language composer: one panel per
/// `NaturalSearchState` that has something to say or to ask, floating above
/// the input field. Restores the state rendering the old `NaturalJourneySheet`
/// carried, adapted to the bottom container the composer lives in now.
struct NaturalJourneyStatePanel: View {
    var dialogue: NaturalJourneyDialogue
    /// The criteria the last finished answer produced, shown by the failure
    /// panel so an offline retry keeps what was already understood.
    var criteria: NaturalJourneyCriteria?

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
        switch dialogue.state {
        case .dismissed, .input, .loading, .onboarding:
            // No panel: the field itself carries these states, including the
            // thinking treatment while a request is in flight. The shell owns
            // onboarding because it replaces the whole sheet surface.
            EmptyView()
        case let .clarification(draft, field):
            NaturalJourneyClarificationView(
                draft: draft,
                field: field,
                onResolveTime: { date, meaning in
                    dialogue.resolve(
                        draft: draft,
                        with: .time(requestedAt: date, represents: meaning),
                    )
                },
                onResolvePlace: { candidate in
                    dialogue.resolve(
                        draft: draft,
                        with: .place(field: field, candidate: candidate),
                    )
                },
                onModify: dialogue.modifyQuery,
            )
        case let .decision(draft, decision):
            NaturalJourneyDecisionView(
                decision: decision,
                onConfirmCurrentLocation: {
                    dialogue.resolve(draft: draft, with: .currentLocationConfirmed)
                },
                onResolveInterpretationConflict: dialogue.modifyQuery,
                onContinueAfterUnexplainedText: {
                    dialogue.resolve(draft: draft, with: .continueAfterUnexplainedText)
                },
                onChooseMissingSavedPlace: { target, kind, savesPlace in
                    dialogue.chooseSavedPlace(
                        draft: draft,
                        target: target,
                        kind: kind,
                        savesPlace: savesPlace,
                    )
                },
                onResolveMode: { mode, constraint in
                    dialogue.resolve(
                        draft: draft,
                        with: .modeConflict(mode: mode, keeping: constraint),
                    )
                },
                onContinueWithoutUnsupported: {
                    dialogue.resolve(
                        draft: draft,
                        with: .continueWithoutUnsupportedConstraints,
                    )
                },
                onResolveTimeConflict: { constraint in
                    dialogue.resolve(
                        draft: draft,
                        with: .timeConflict(keeping: constraint),
                    )
                },
                onModify: dialogue.modifyQuery,
            )
        case let .unsupported(message, suggestions):
            NaturalJourneyUnsupportedView(
                message: message,
                suggestions: suggestions,
                feedbackPhrase: dialogue.query,
                onModify: dialogue.modifyQuery,
                onClassicSearch: dialogue.useClassicSearch,
            )
        case let .availability(guidance):
            NaturalJourneyAvailabilityView(
                guidance: guidance,
                onRetry: dialogue.retryAvailability,
                onClassicSearch: dialogue.useClassicSearch,
            )
        case let .failed(message):
            NaturalJourneyFailureView(
                message: message,
                criteria: criteria,
                unresolvedDraft: dialogue.unresolvedDraft,
                feedbackPhrase: dialogue.query,
                onRetry: dialogue.retry,
                onClassicSearch: dialogue.useClassicSearch,
            )
        }
    }
}
