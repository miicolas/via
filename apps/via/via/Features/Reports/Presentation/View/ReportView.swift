import SwiftUI

struct ReportView: View {
    let viewModel: ReportViewModel

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.sheetTabVisibilityProgress) private var tabVisibilityProgress

    var body: some View {
        @Bindable var viewModel = viewModel

        NavigationStack {
            Group {
                if case .confirmed(let submission) = viewModel.submissionState {
                    ReportConfirmationView(
                        submission: submission,
                        onDone: viewModel.finishConfirmation
                    )
                } else {
                    reportsContent
                }
            }
            .transition(reduceMotion ? .identity : .opacity)
            .animation(reduceMotion ? nil : .smooth(duration: 0.25), value: isShowingConfirmation)
            .navigationTitle(isShowingConfirmation ? "" : "Signaler")
            .toolbarTitleDisplayMode(.inlineLarge)
            .toolbarVisibility(isShowingConfirmation ? .hidden : .visible, for: .navigationBar)
        }
        .opacity(tabVisibilityProgress)
        .task {
            viewModel.loadIfNeeded()
        }
        .sheet(item: $viewModel.presentedSheet) { destination in
            switch destination {
            case .stationPicker:
                ReportStationPickerView(viewModel: viewModel)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)

            case .crowdingPicker:
                CrowdingLevelPickerView(
                    onSelect: viewModel.selectCrowdingLevel,
                    onCancel: viewModel.cancelPresentedSheet
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
        }
        .haptic(Haptic.commit, on: viewModel.presentedSheet) { previous, current in
            previous == nil && current != nil
        }
        .haptic(Haptic.commit, on: viewModel.submissionCommitTrigger)
        .haptic(Haptic.selection, on: viewModel.stationSelectionTrigger)
        .haptic(Haptic.tap, on: viewModel.sheetCancellationTrigger)
        .haptic(Haptic.commit, on: viewModel.confirmationDoneTrigger)
        .haptic(Haptic.failed, on: isShowingSubmissionError) { !$0 && $1 }
    }

    private var reportsContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                ReportContextView(
                    state: viewModel.contextResolver.state,
                    isEditable: isContextEditable,
                    onChooseStation: viewModel.presentStationPicker,
                    onRetry: viewModel.retryContextResolution
                )

                if case .failed(_, let error) = viewModel.submissionState {
                    submissionError(error)
                }

                GlassEffectContainer(spacing: 14) {
                    LazyVGrid(columns: columns, spacing: 18) {
                        ForEach(categories, id: \.self) { category in
                            ReportActionView(
                                title: category.compactTitle,
                                accessibilityTitle: category.title,
                                systemImage: category.systemImage,
                                tint: category.tint,
                                accessibilityHint: category.explanation,
                                isEnabled: viewModel.canSubmit,
                                isLoading: viewModel.submissionState.submittingCategory == category
                            ) {
                                viewModel.selectCategory(category)
                            }
                        }
                    }
                }

                privacyNotice
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
            .padding(.bottom, 24)
            .frame(maxWidth: 720, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .scrollEdgeEffectStyle(.soft, for: .vertical)
    }

    private var categories: [ReportCategory] {
        ReportCategoryGroup.allCases.flatMap(\.categories)
    }

    private var columns: [GridItem] {
        let minimum: CGFloat = dynamicTypeSize.isAccessibilitySize ? 140 : 92
        let maximum: CGFloat = dynamicTypeSize.isAccessibilitySize ? 220 : 120
        return [GridItem(.adaptive(minimum: minimum, maximum: maximum), spacing: 14)]
    }

    private func submissionError(_ error: ViaError) -> some View {
        EmptyStateView(
            .unavailable(
                title: "Signalement non envoyé",
                message: message(for: error)
            )
        ) {
            RetryButton(action: viewModel.retrySubmission)
                .primaryAction(tint: .blue)
        }
        .background(.orange.opacity(0.1), in: RoundedRectangle(
            cornerRadius: 22,
            style: .continuous
        ))
    }

    private var privacyNotice: some View {
        Label("Votre identité n’est pas affichée", systemImage: "hand.raised.fill")
            .font(.footnote.weight(.medium))
            .foregroundStyle(.secondary)
            .accessibilityHint("Via utilise votre compte uniquement pour prévenir les abus.")
            .frame(maxWidth: .infinity, alignment: .center)
    }

    private var isShowingConfirmation: Bool {
        if case .confirmed = viewModel.submissionState { return true }
        return false
    }

    private var isContextEditable: Bool {
        if case .idle = viewModel.submissionState { return true }
        return false
    }

    private var isShowingSubmissionError: Bool {
        if case .failed = viewModel.submissionState { return true }
        return false
    }

    private func message(for error: ViaError) -> String {
        switch error {
        case .rateLimited:
            "Trop de signalements ont été envoyés. Réessayez dans un instant."
        case .unavailable, .server:
            "Le service est momentanément indisponible. Votre choix a été conservé."
        case .invalidConfiguration, .invalidRequest, .transport, .decoding, .unauthorized:
            "Impossible d’envoyer le signalement. Votre choix a été conservé."
        }
    }
}
