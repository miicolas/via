import SwiftUI

struct JourneyDetailView: View {
    let journey: Journey
    let destination: JourneyDestination
    let source: JourneyResult.Source?
    let activeJourneyModel: ActiveJourneyModel
    let onHighlightSection: (String?) -> Void
    let onExpandMap: () -> Void

    @State private var expandedSectionIDs: Set<String>
    @State private var highlightedSectionID: String?
    @State private var isActivationExplanationPresented = false
    @State private var isActivating = false

    @Environment(\.dismiss) private var dismiss

    init(
        journey: Journey,
        destination: JourneyDestination,
        source: JourneyResult.Source?,
        activeJourneyModel: ActiveJourneyModel,
        onHighlightSection: @escaping (String?) -> Void,
        onExpandMap: @escaping () -> Void
    ) {
        self.journey = journey
        self.destination = destination
        self.source = source
        self.activeJourneyModel = activeJourneyModel
        self.onHighlightSection = onHighlightSection
        self.onExpandMap = onExpandMap
        _expandedSectionIDs = State(initialValue: [])
        _highlightedSectionID = State(initialValue: nil)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                JourneyDetailSummaryView(journey: journey, source: source)

                if !journey.warnings.isEmpty {
                    JourneyWarningBanner(warnings: journey.warnings)
                }

                Text("Votre trajet")
                    .font(.title2.weight(.bold))

                JourneyTimelineView(
                    journey: journey,
                    expandedSectionIDs: $expandedSectionIDs,
                    highlightedSectionID: highlightedSectionID,
                    onSelectSection: selectSection
                )
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .navigationTitle("Détail du trajet")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(role: .close) {
                    dismiss()
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Carte", systemImage: "map", action: expandMap)
                    .accessibilityHint("Réduit la fiche pour explorer le trajet sur la carte")
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            actionBar
        }
        .journeyTrackingAlert(isPresented: $isActivationExplanationPresented) {
            go(allowsBackgroundTracking: $0)
        }
        .onAppear {
            onHighlightSection(highlightedSectionID)
        }
        .onDisappear {
            onHighlightSection(nil)
        }
    }

    private var actionBar: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            let action = action(at: context.date)
            Button {
                handleAction(action)
            } label: {
                HStack(spacing: 9) {
                    if isActivating {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                    }
                    Text(action.title)
                        .font(.headline)
                }
            }
            .primaryAction()
            .disabled(isActivating || action == .active)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.bar)
            .accessibilityHint(
                action == .active
                    ? "Ce trajet est déjà actif"
                    : "Active le guidage étape par étape dans Via"
            )
        }
    }

    private func action(at date: Date) -> JourneyActivationAction {
        activeJourneyModel.activationAction(for: journey, at: date)
    }

    private func selectSection(_ sectionID: String) {
        highlightedSectionID = sectionID
        onHighlightSection(sectionID)
    }

    private func expandMap() {
        onHighlightSection(highlightedSectionID)
        onExpandMap()
    }

    private func handleAction(_ action: JourneyActivationAction) {
        switch action {
        case .go:
            isActivationExplanationPresented = true
        case .activate:
            perform {
                await activeJourneyModel.activate(
                    journey: journey,
                    destination: destination,
                    source: source
                )
            }
        case .resume:
            perform { await activeJourneyModel.resume() }
        case .active:
            break
        }
    }

    private func go(allowsBackgroundTracking: Bool) {
        perform {
            await activeJourneyModel.go(
                journey: journey,
                destination: destination,
                source: source,
                allowsBackgroundTracking: allowsBackgroundTracking
            )
        }
    }

    private func perform(_ operation: @escaping @MainActor () async -> Void) {
        isActivating = true
        Task {
            await operation()
            isActivating = false
        }
    }
}
