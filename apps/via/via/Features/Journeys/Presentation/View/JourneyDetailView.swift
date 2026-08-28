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
    var journeyShareRepository: any JourneyShareRepository = InMemoryJourneyShareRepository()
    let onSelectDeparture: (JourneyDepartureChoice, String) -> Void
    let onRetryDepartures: () async -> Void
    let onUpdateTime: (Date, JourneyDatetimeRepresents) async throws -> Void
    var prefersGoAction = false
    var prefersPlanAction = false
    var isCompact = false
    let onExpandMap: () -> Void

    @State private var expandedSectionIDs: Set<String> = []
    @State private var isActivationExplanationPresented = false
    @State private var isActivating = false
    @State private var isReminderSheetPresented = false
    @State private var isDraftErrorPresented = false
    @State private var editedTimeEndpoint: JourneyDatetimeRepresents?
    @State private var shareLink: JourneyShareLink?
    @State private var isPreparingShare = false
    @State private var shareErrorMessage: String?
    @State private var shareActionTick = 0
    @State private var shareOutcomeTick = 0

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

                if !JourneyWarningPresentation.visibleWarnings(from: journey.warnings).isEmpty {
                    JourneyWarningBanner(warnings: journey.warnings)
                        .padding(.horizontal, 20)
                        .padding(.top, 18)
                }

                Divider()
                    .padding(.top, 28)

                LiveJourneyTimelineView(
                    journey: journey,
                    expandedSectionIDs: $expandedSectionIDs,
                    departureChoices: departureChoicesModel,
                    revisableSectionIDs: ActiveJourneyRules.revisableSectionIDs(
                        in: journey,
                        currentSectionIndex: nil,
                        isTracking: false,
                        at: .now
                    ),
                    onSelectDeparture: onSelectDeparture,
                    onRetryDepartures: { Task { await onRetryDepartures() } }
                )
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 34)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        // The compact summary lives in the sheet container; keep this scroll
        // content out of the peek while leaving the action bar available.
        .opacity(isCompact ? 0 : 1)
        .accessibilityHidden(isCompact)
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
        .sheet(item: $shareLink) { link in
            JourneyShareLinkSheetView(link: link, journey: journey)
        }
        .haptic(Haptic.failed, on: isDraftErrorPresented) { !$0 && $1 }
        .haptic(Haptic.saved, on: shareOutcomeTick)
        .alert("Trajet non prévu", isPresented: $isDraftErrorPresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(
                plannedJourneyDraftModel.lastError
                    ?? "Le trajet n’a pas pu être enregistré sur cet appareil."
            )
        }
        .alert(
            "Partage indisponible",
            isPresented: Binding(
                get: { shareErrorMessage != nil },
                set: { if !$0 { shareErrorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(shareErrorMessage ?? "Le lien de partage n’a pas pu être créé.")
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
            Button {
                prepareShare()
            } label: {
                Label {
                    Text("Partager le trajet")
                } icon: {
                    Image(systemName: isPreparingShare ? "hourglass" : "square.and.arrow.up")
                        .stateSymbolTransition(value: isPreparingShare)
                }
            }
            .labelStyle(.iconOnly)
            .disabled(isPreparingShare)
            .accessibilityValue(isPreparingShare ? "Préparation" : "Prêt à partager")
            .haptic(Haptic.commit, on: shareActionTick)
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

    private func expandMap() {
        onExpandMap()
    }

    private func prepareShare() {
        guard !isPreparingShare else { return }
        shareActionTick += 1
        isPreparingShare = true
        Task { @MainActor in
            defer { isPreparingShare = false }
            do {
                shareLink = try await journeyShareRepository.create(for: journey)
                shareOutcomeTick += 1
            } catch {
                shareErrorMessage = shareMessage(for: error.via)
            }
        }
    }

    private func shareMessage(for error: ViaError) -> String {
        switch error {
        case .rateLimited:
            "Trop de liens ont été créés récemment. Réessayez dans un instant."
        case .unavailable, .transport:
            "Vérifiez votre connexion puis réessayez."
        default:
            "Le lien de partage n’a pas pu être créé. Réessayez dans un instant."
        }
    }

    private func handleAction(_ action: JourneyActivationAction) {
        switch action {
        case .go:
            isActivationExplanationPresented = true
        case .plan:
            perform {
                let didPlan = await JourneyActivation.plan(
                    journey: journey,
                    destination: destination,
                    source: source,
                    planningPolicy: planningPolicy,
                    draftModel: plannedJourneyDraftModel
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
        await JourneyReminderEditing.save(
            journey: journey,
            destination: destination,
            source: source,
            planningPolicy: planningPolicy,
            leadTime: leadTime,
            coordinator: journeyNotificationCoordinator
        )
    }

    private func cancelReminder() async -> String? {
        await JourneyReminderEditing.cancel(coordinator: journeyNotificationCoordinator)
    }

    private func go(allowsBackgroundTracking: Bool) {
        perform {
            await JourneyActivation.go(
                journey: journey,
                destination: destination,
                source: source,
                planningPolicy: planningPolicy,
                activeJourneyModel: activeJourneyModel,
                plannedJourneyDraftModel: plannedJourneyDraftModel,
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
