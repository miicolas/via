import SwiftUI

struct JourneyDetailView: View {
  let journey: Journey
  let destination: JourneyDestination
  let source: JourneyResult.Source?
  let activeJourneyModel: ActiveJourneyModel
  let journeyNotificationCoordinator: JourneyNotificationCoordinator
  let prefersGoAction: Bool
  let onHighlightSection: (String?) -> Void
  let onExpandMap: () -> Void

  @State private var expandedSectionIDs: Set<String>
  @State private var highlightedSectionID: String?
  @State private var isActivationExplanationPresented = false
  @State private var isActivating = false
  @State private var isReminderSheetPresented = false

  @Environment(\.dismiss) private var dismiss

  init(
    journey: Journey,
    destination: JourneyDestination,
    source: JourneyResult.Source?,
    activeJourneyModel: ActiveJourneyModel,
    journeyNotificationCoordinator: JourneyNotificationCoordinator = .preview,
    prefersGoAction: Bool = false,
    onHighlightSection: @escaping (String?) -> Void,
    onExpandMap: @escaping () -> Void
  ) {
    self.journey = journey
    self.destination = destination
    self.source = source
    self.activeJourneyModel = activeJourneyModel
    self.journeyNotificationCoordinator = journeyNotificationCoordinator
    self.prefersGoAction = prefersGoAction
    self.onHighlightSection = onHighlightSection
    self.onExpandMap = onExpandMap
    _expandedSectionIDs = State(initialValue: [])
    _highlightedSectionID = State(initialValue: nil)
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 28) {
        JourneyDetailSummaryView(journey: journey, source: source)

        if !journey.warnings.isEmpty {
          JourneyWarningBanner(warnings: journey.warnings)
        }

        JourneyGuidanceOverviewView(sections: journey.sections)

        JourneyDetailTimelineSection(
          journey: journey,
          expandedSectionIDs: $expandedSectionIDs,
          highlightedSectionID: highlightedSectionID,
          onSelectSection: selectSection
        )
      }
      .padding(.horizontal, 16)
      .padding(.top, 12)
      .padding(.bottom, 24)
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
    .onAppear {
      onHighlightSection(highlightedSectionID)
    }
    .onDisappear {
      onHighlightSection(nil)
    }
  }

  private func action(at date: Date) -> JourneyActivationAction {
    if prefersGoAction, activeJourneyModel.session?.journey.id != journey.id {
      return .go
    }
    return activeJourneyModel.activationAction(for: journey, at: date)
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
        source: source
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
