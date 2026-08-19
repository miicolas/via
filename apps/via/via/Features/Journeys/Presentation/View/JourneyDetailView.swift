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
        let firstSectionID = journey.sections.first?.id
        _expandedSectionIDs = State(initialValue: Set([firstSectionID].compactMap { $0 }))
        _highlightedSectionID = State(initialValue: firstSectionID)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                JourneyDetailSummaryView(journey: journey, source: source)

                Button(action: expandMap) {
                    JourneyOverviewMapView(
                        presentation: JourneyMapPresentation(journey: journey),
                        highlightedSectionID: highlightedSectionID
                    )
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay(alignment: .bottomTrailing) {
                        Label("Agrandir", systemImage: "arrow.up.left.and.arrow.down.right")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 11)
                            .padding(.vertical, 8)
                            .background(.regularMaterial, in: Capsule())
                            .padding(10)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Carte du trajet")
                .accessibilityHint("Réduit la fiche pour explorer le trajet sur la grande carte")

                if !journey.warnings.isEmpty {
                    JourneyWarningBanner(warnings: journey.warnings)
                }

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
        .safeAreaInset(edge: .bottom, spacing: 0) {
            actionBar
        }
        .alert("Suivre ce trajet en temps réel ?", isPresented: $isActivationExplanationPresented) {
            Button("Continuer") {
                activate(requestBackgroundAuthorization: true)
            }
            Button("Sans suivi en arrière-plan") {
                activate(requestBackgroundAuthorization: false)
            }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text(
                "Via utilise votre position pendant le trajet pour afficher la bonne étape, " +
                    "détecter l’arrivée et proposer rapidement un nouvel itinéraire. " +
                    "Vous pourrez continuer manuellement si vous refusez."
            )
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
            Button {
                if activeJourneyModel.session?.journey.id == journey.id {
                    activate(requestBackgroundAuthorization: false)
                } else {
                    isActivationExplanationPresented = true
                }
            } label: {
                HStack(spacing: 9) {
                    if isActivating {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                    }
                    Text(action(at: context.date).title)
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: 52)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .disabled(isActivating)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.bar)
            .accessibilityHint("Active le guidage étape par étape dans Via")
        }
    }

    private func action(at date: Date) -> JourneyActivationAction {
        ActiveJourneyRules.activationAction(
            for: journey,
            activeJourneyID: activeJourneyModel.session?.journey.id,
            now: date
        )
    }

    private func selectSection(_ sectionID: String) {
        highlightedSectionID = sectionID
        onHighlightSection(sectionID)
    }

    private func expandMap() {
        onHighlightSection(highlightedSectionID)
        onExpandMap()
    }

    private func activate(requestBackgroundAuthorization: Bool) {
        isActivating = true
        Task {
            await activeJourneyModel.activate(
                journey: journey,
                destination: destination,
                source: source,
                requestBackgroundAuthorization: requestBackgroundAuthorization
            )
            isActivating = false
        }
    }
}
