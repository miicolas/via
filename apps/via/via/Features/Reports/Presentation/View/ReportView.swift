import SwiftUI

struct ReportView: View {
    let viewModel: ReportViewModel

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.sheetTabVisibilityProgress) private var tabVisibilityProgress

    var body: some View {
        @Bindable var viewModel = viewModel

        NavigationStack {
            Group {
                if case .confirmed = viewModel.submissionState {
                    ReportConfirmationView(onDone: viewModel.finishConfirmation)
                } else {
                    reportsContent
                }
            }
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
    }

    private var reportsContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 28) {
                Text("Partagez ce que vous observez pour mieux informer les voyageurs.")
                    .font(.body)
                    .foregroundStyle(.secondary)

                ReportContextView(
                    state: viewModel.contextResolver.state,
                    isEditable: isContextEditable,
                    onChooseStation: viewModel.presentStationPicker,
                    onRetry: viewModel.retryContextResolution
                )

                if case .failed(_, let error) = viewModel.submissionState {
                    submissionError(error)
                }

                ForEach(ReportCategoryGroup.allCases, id: \.self) { group in
                    reportSection(group)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Dans mon train")
                        .font(.title3.weight(.bold))

                    GlassEffectContainer(spacing: 12) {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ReportCardView(
                                title: "Climatisation présente",
                                systemImage: "snowflake",
                                tint: .cyan,
                                subtitle: "Disponible pendant un trajet en direct",
                                isEnabled: false,
                                action: {}
                            )
                        }
                    }
                }

                Text("Les signalements sont anonymes et conservés uniquement pendant cette session.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 24)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
        }
        .scrollEdgeEffectStyle(.soft, for: .vertical)
    }

    private func reportSection(_ group: ReportCategoryGroup) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(group.title)
                .font(.title3.weight(.bold))

            GlassEffectContainer(spacing: 12) {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(group.categories, id: \.self) { category in
                        ReportCardView(
                            title: category.title,
                            systemImage: category.systemImage,
                            tint: category.tint,
                            isEnabled: viewModel.canSubmit,
                            isLoading: viewModel.submissionState.submittingCategory == category
                        ) {
                            viewModel.selectCategory(category)
                        }
                    }
                }
            }
        }
    }

    private func submissionError(_ error: ViaError) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Signalement non envoyé", systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundStyle(.orange)

            Text(message(for: error))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button("Réessayer", action: viewModel.retrySubmission)
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.orange.opacity(0.1), in: RoundedRectangle(
            cornerRadius: 20,
            style: .continuous
        ))
    }

    private var columns: [GridItem] {
        if dynamicTypeSize.isAccessibilitySize {
            return [GridItem(.flexible())]
        }
        return [GridItem(.flexible()), GridItem(.flexible())]
    }

    private var isShowingConfirmation: Bool {
        if case .confirmed = viewModel.submissionState { return true }
        return false
    }

    private var isContextEditable: Bool {
        if case .idle = viewModel.submissionState { return true }
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
