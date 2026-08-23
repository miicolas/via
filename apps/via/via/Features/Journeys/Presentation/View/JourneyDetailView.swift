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
  var prefersGoAction: Bool = false
  var prefersPlanAction: Bool = false
  let onHighlightSection: (String?) -> Void
  let onExpandMap: () -> Void

  @State private var expandedSectionIDs: Set<String> = []
  @State private var highlightedSectionID: String?
  @State private var isActivationExplanationPresented = false
  @State private var isActivating = false
  @State private var isReminderSheetPresented = false
  @State private var isDraftErrorPresented = false

  @Environment(\.dismiss) private var dismiss

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        JourneyDetailSummaryView(journey: journey, source: source)

        if !journey.warnings.isEmpty {
          JourneyWarningBanner(warnings: journey.warnings)
        }

        JourneyTimelineView(
          journey: journey,
          expandedSectionIDs: $expandedSectionIDs,
          highlightedSectionID: highlightedSectionID,
          onSelectSection: selectSection,
          departureChoices: departureChoicesModel,
          revisableSectionIDs: ActiveJourneyRules.revisableSectionIDs(
            in: journey,
            progress: nil,
            isTracking: false,
            at: .now
          ),
          onSelectDeparture: onSelectDeparture,
          onRetryDepartures: { Task { await onRetryDepartures() } }
        )
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.secondary.opacity(0.055), in: RoundedRectangle(cornerRadius: 22))
      }
      .padding(.horizontal, 16)
      .padding(.top, 12)
      .padding(.bottom, 16)
      .frame(maxWidth: .infinity, alignment: .leading)
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
          .labelStyle(.iconOnly)
          .accessibilityHint("Réduit la fiche pour explorer le trajet sur la carte")
      }
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
    }
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

  private func action(at date: Date) -> JourneyActivationAction {
    ActiveJourneyRules.detailAction(
      activeAction: activeJourneyModel.activationAction(for: journey, at: date),
      isPlanned: isPlannedDraft,
      prefersGo: prefersGoAction,
      prefersPlan: prefersPlanAction
    )
  }

  /// Deleting the plan closes the detail as well: the sheet may have been
  /// opened for the draft itself, which no longer exists to resolve it.
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
