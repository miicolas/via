import SwiftUI

struct JourneyDetailView: View {
    let journey: Journey
    let destination: JourneyDestination
    let source: JourneyResult.Source?
    let activeJourneyModel: ActiveJourneyModel
    let plannedJourneyDraftModel: PlannedJourneyDraftModel
    var journeyNotificationCoordinator: JourneyNotificationCoordinator = .preview
    let planningPolicy: JourneyPlanningPolicy
    let departureChoicesModel: JourneyDepartureChoicesModel
    let onSelectDeparture: (JourneyDepartureChoice, String) -> Void
    let onRetryDepartures: () async -> Void
    let onUpdateTime: (Date, JourneyDatetimeRepresents) async throws -> Void
    var prefersGoAction = false
    var prefersPlanAction = false
    let onHighlightSection: (String?) -> Void
    let onExpandMap: () -> Void

    @State private var expandedSectionIDs: Set<String> = []
    @State private var highlightedSectionID: String?
    @State private var isActivationExplanationPresented = false
    @State private var isActivating = false
    @State private var isReminderSheetPresented = false
    @State private var isDraftErrorPresented = false
    @State private var editedTimeEndpoint: JourneyDatetimeRepresents?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                JourneyDetailHeaderView(
                    journey: journey,
                    source: source
                )
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 22)

                JourneyDetailSummaryView(
                    journey: journey,
                    source: source,
                    canEditTimes: activeJourneyModel.session?.journey.id != journey.id,
                    onEditTime: { editedTimeEndpoint = $0 }
                )
                    .padding(.horizontal, 20)

                if !journey.warnings.isEmpty {
                    JourneyWarningBanner(warnings: journey.warnings)
                        .padding(.horizontal, 20)
                        .padding(.top, 18)
                }

                Divider()
                    .padding(.top, 28)

                LiveJourneyTimelineView(
                    journey: journey,
                    progress: nil,
                    expandedSectionIDs: $expandedSectionIDs,
                    highlightedSectionID: highlightedSectionID,
                    departureChoices: departureChoicesModel,
                    revisableSectionIDs: ActiveJourneyRules.revisableSectionIDs(
                        in: journey,
                        progress: nil,
                        isTracking: false,
                        at: .now
                    ),
                    onSelectSection: selectSection,
                    onSelectDeparture: onSelectDeparture,
                    onRetryDepartures: { Task { await onRetryDepartures() } }
                )
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 34)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.hidden)
        .background(Color(uiColor: .systemBackground))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { journeyToolbar }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            JourneyDetailActionBar(
                isActivating: isActivating,
                isReminderScheduled: isReminderScheduled,
                isUpdatingReminder: journeyNotificationCoordinator.isUpdatingReminder,
                actionAt: action,
                onAction: handleAction,
                onReminder: { isReminderSheetPresented = true }
            )
        }
        .journeyTrackingAlert(isPresented: $isActivationExplanationPresented) {
            go(allowsBackgroundTracking: $0)
        }
        .sheet(isPresented: $isReminderSheetPresented) {
            JourneyReminderTimingSheet(
                initialLeadTime: journeyNotificationCoordinator.preferences.departureLeadTime,
                isScheduled: isReminderScheduled,
                authorizationDenied: journeyNotificationCoordinator.authorizationStatus == .denied,
                onSave: saveReminder,
                onCancel: cancelReminder
            )
            .presentationDetents([.medium, .large])
            .presentationCornerRadius(36)
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $editedTimeEndpoint) { endpoint in
            JourneyTimeEditorSheet(
                journey: journey,
                endpoint: endpoint,
                tint: .accentColor,
                onApply: onUpdateTime
            )
            .presentationDetents([.height(520)])
            .presentationCornerRadius(36)
            .presentationDragIndicator(.visible)
        }
        .alert("Trajet non prévu", isPresented: $isDraftErrorPresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(
                plannedJourneyDraftModel.lastError
                    ?? "Le trajet n’a pas pu être enregistré sur cet appareil."
            )
        }
        .onAppear {
            onHighlightSection(highlightedSectionID)
        }
        .onDisappear {
            onHighlightSection(nil)
        }
    }

    private var isPlannedDraft: Bool {
        plannedJourneyDraftModel.draft?.journey.id == journey.id
    }

    @ToolbarContentBuilder
    private var journeyToolbar: some ToolbarContent {
        if isPlannedDraft {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Supprimer le trajet prévu", systemImage: "trash", role: .destructive) {
                    discardPlannedDraft()
                }
                .labelStyle(.iconOnly)
                .disabled(isActivating)
                .accessibilityHint("Supprime ce trajet prévu de cet appareil")
            }
        }

        ToolbarItem(placement: .topBarTrailing) {
            Button("Afficher la carte", systemImage: "map", action: expandMap)
                .labelStyle(.iconOnly)
                .accessibilityHint("Réduit la fiche pour explorer le trajet sur la carte")
        }

        ToolbarItem(placement: .topBarTrailing) {
            Button("Fermer", systemImage: "xmark", role: .close) {
                dismiss()
            }
            .labelStyle(.iconOnly)
        }
    }

    private func action(at date: Date) -> JourneyActivationAction {
        ActiveJourneyRules.detailAction(
            activeAction: activeJourneyModel.activationAction(for: journey, at: date),
            isPlanned: isPlannedDraft,
            prefersGo: prefersGoAction,
            prefersPlan: prefersPlanAction
        )
    }

    private func discardPlannedDraft() {
        perform {
            await plannedJourneyDraftModel.discard()
            dismiss()
        }
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
        case .plan:
            perform {
                let didPlan = await plannedJourneyDraftModel.plan(
                    journey: journey,
                    destination: destination,
                    source: source,
                    planningPolicy: planningPolicy
                )
                isDraftErrorPresented = !didPlan
            }
        case .resume:
            perform { await activeJourneyModel.resume() }
        case .planned, .active:
            break
        }
    }

    private var isReminderScheduled: Bool {
        journeyNotificationCoordinator.scheduledJourneyID == journey.id
    }

    private func saveReminder(
        _ leadTime: JourneyNotificationPreferences.DepartureLeadTime
    ) async -> String? {
        if journeyNotificationCoordinator.preferences.departureLeadTime != leadTime {
            await journeyNotificationCoordinator.updateDepartureLeadTime(leadTime)
            guard journeyNotificationCoordinator.preferences.departureLeadTime == leadTime else {
                return journeyNotificationCoordinator.lastError
            }
        }

        if !isReminderScheduled {
            await journeyNotificationCoordinator.scheduleReminder(
                for: journey,
                destination: destination,
                source: source,
                planningPolicy: planningPolicy
            )
        }

        return journeyNotificationCoordinator.lastError
    }

    private func cancelReminder() async -> String? {
        await journeyNotificationCoordinator.cancelReminder()
        return journeyNotificationCoordinator.lastError
    }

    private func go(allowsBackgroundTracking: Bool) {
        perform {
            if plannedJourneyDraftModel.draft?.journey.id == journey.id {
                await plannedJourneyDraftModel.launch(
                    using: activeJourneyModel,
                    allowsBackgroundTracking: allowsBackgroundTracking
                )
                return
            }
            await activeJourneyModel.go(
                journey: journey,
                destination: destination,
                source: source,
                planningPolicy: planningPolicy,
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
