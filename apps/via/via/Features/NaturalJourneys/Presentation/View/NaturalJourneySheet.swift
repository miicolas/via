import SwiftUI

struct NaturalJourneySheet: View {
    let viewModel: SearchViewModel
    @Binding var detent: PresentationDetent

    @FocusState private var isInputFocused: Bool

    var body: some View {
        @Bindable var viewModel = viewModel

        NavigationStack {
            ScrollView {
                content(viewModel: $viewModel)
                    .frame(maxWidth: 560)
                    .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Recherche intelligente")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .close) {
                        viewModel.dismissNaturalSearch()
                    }
                }
            }
        }
        .onChange(of: viewModel.naturalSearchState, initial: true) { _, state in
            if NaturalJourneyPresentationPolicy.expandsForInput(state) {
                detent = .large
                Task { @MainActor in isInputFocused = true }
            } else {
                isInputFocused = false
            }
        }
    }

    @ViewBuilder
    private func content(viewModel: Bindable<SearchViewModel>) -> some View {
        switch viewModel.wrappedValue.naturalSearchState {
        case .onboarding:
            AIOnboardingCard(onTry: viewModel.wrappedValue.showNaturalSearchInput)
        case .input:
            NaturalJourneyInputView(
                query: viewModel.naturalQuery,
                isFocused: $isInputFocused,
                onSubmit: viewModel.wrappedValue.submitNaturalSearch,
            )
        case .loading:
            NaturalJourneyLoadingView(phrase: viewModel.wrappedValue.naturalQuery)
        case let .clarification(draft, field):
            NaturalJourneyClarificationView(
                draft: draft,
                field: field,
                onResolveTime: { date, meaning in
                    viewModel.wrappedValue.resolveNaturalTime(
                        draft: draft,
                        requestedAt: date,
                        represents: meaning,
                    )
                },
                onResolvePlace: { candidate in
                    viewModel.wrappedValue.resolveNaturalPlace(
                        draft: draft,
                        field: field,
                        candidate: candidate,
                    )
                },
                onModify: viewModel.wrappedValue.modifyNaturalQuery,
            )
        case let .decision(draft, decision):
            NaturalJourneyDecisionView(
                decision: decision,
                onConfirmCurrentLocation: {
                    viewModel.wrappedValue.confirmNaturalCurrentLocation(draft: draft)
                },
                onResolveMode: { mode, constraint in
                    viewModel.wrappedValue.resolveNaturalModeConflict(
                        draft: draft,
                        mode: mode,
                        keeping: constraint,
                    )
                },
                onContinueWithoutUnsupported: {
                    viewModel.wrappedValue.continueNaturalSearchWithoutUnsupportedConstraints(
                        draft: draft,
                    )
                },
                onResolveTimeConflict: { constraint in
                    viewModel.wrappedValue.resolveNaturalTimeConflict(
                        draft: draft,
                        keeping: constraint,
                    )
                },
                onModify: viewModel.wrappedValue.modifyNaturalQuery,
            )
        case let .unsupported(message, suggestions):
            NaturalJourneyUnsupportedView(
                message: message,
                suggestions: suggestions,
                onModify: viewModel.wrappedValue.modifyNaturalQuery,
                onClassicSearch: viewModel.wrappedValue.useClassicSearch,
            )
        case let .availability(guidance):
            NaturalJourneyAvailabilityView(
                guidance: guidance,
                onRetry: viewModel.wrappedValue.openNaturalSearch,
                onClassicSearch: viewModel.wrappedValue.useClassicSearch,
            )
        case let .failed(message):
            NaturalJourneyFailureView(
                message: message,
                criteria: viewModel.wrappedValue.naturalJourneyCriteria,
                onRetry: viewModel.wrappedValue.retryNaturalSearch,
                onClassicSearch: viewModel.wrappedValue.useClassicSearch,
            )
        }
    }
}
