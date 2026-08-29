import Foundation

/// Coordinates the independent launch restores and the notification work that
/// must happen after them. Keeping this ordering outside the scene declaration
/// makes the composition root describe *what* starts, not the startup protocol.
@MainActor
enum ApplicationLifecycle {
    static func restore(
        authSessionViewModel: AuthSessionViewModel,
        accountModel: AccountModel,
        notificationScheduleCoordinator: NotificationScheduleCoordinator,
        journeyNotificationCoordinator: JourneyNotificationCoordinator,
        activeJourneyModel: ActiveJourneyModel,
        plannedJourneyDraftModel: PlannedJourneyDraftModel,
        pushNotificationManager: PushNotificationManager
    ) async {
        async let auth: Void = authSessionViewModel.restore()
        async let notifications: Void = journeyNotificationCoordinator.restore()
        async let activeJourney: Void = activeJourneyModel.restore()
        async let plannedJourney: Void = plannedJourneyDraftModel.restore()

        await auth
        await notificationScheduleCoordinator.reconcile(
            schedules: accountModel.notificationSchedules,
            preferences: accountModel.notificationPreferences
        )
        await notifications
        await activeJourney
        await plannedJourney
        await pushNotificationManager.setNotificationsAuthorized(
            journeyNotificationCoordinator.isAuthorized
        )
        await pushNotificationManager.flush()
    }
}
