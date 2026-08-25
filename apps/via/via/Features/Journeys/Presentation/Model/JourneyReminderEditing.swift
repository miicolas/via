import Foundation

/// Owns the two-step reminder edit used by both search results and detail.
@MainActor
enum JourneyReminderEditing {
    static func save(
        journey: Journey,
        destination: JourneyDestination,
        source: JourneyResult.Source?,
        planningPolicy: JourneyPlanningPolicy,
        leadTime: JourneyNotificationPreferences.DepartureLeadTime,
        coordinator: JourneyNotificationCoordinator
    ) async -> String? {
        if coordinator.preferences.departureLeadTime != leadTime {
            await coordinator.updateDepartureLeadTime(leadTime)
            guard coordinator.preferences.departureLeadTime == leadTime else {
                return coordinator.lastError
            }
        }

        if coordinator.scheduledJourneyID != journey.id {
            await coordinator.scheduleReminder(
                for: journey,
                destination: destination,
                source: source,
                planningPolicy: planningPolicy
            )
        }
        return coordinator.lastError
    }

    static func cancel(coordinator: JourneyNotificationCoordinator) async -> String? {
        await coordinator.cancelReminder()
        return coordinator.lastError
    }
}
