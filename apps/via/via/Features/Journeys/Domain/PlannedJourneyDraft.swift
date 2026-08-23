import Foundation

/// A journey kept ready without starting guidance or location tracking.
///
/// Via deliberately keeps a single draft: planning another journey replaces
/// the previous one, and launching it consumes it.
struct PlannedJourneyDraft: Codable, Sendable, Hashable, Identifiable {
    let journey: Journey
    let destination: JourneyDestination
    let source: JourneyResult.Source?
    let planningPolicy: JourneyPlanningPolicy
    let plannedAt: Date

    var id: JourneyID { journey.id }
}
