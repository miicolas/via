import Foundation

/// The complete context needed to render or revise one journey.
///
/// A journey can arrive from the live session, a reminder, a planned draft or
/// the current search. Keeping those four values together prevents callers
/// from accidentally pairing a journey with the destination or policy of a
/// different surface.
struct JourneyContext: Sendable, Hashable {
    let journey: Journey
    let destination: JourneyDestination
    let source: JourneyResult.Source?
    let planningPolicy: JourneyPlanningPolicy

    init(
        journey: Journey,
        destination: JourneyDestination,
        source: JourneyResult.Source?,
        planningPolicy: JourneyPlanningPolicy
    ) {
        self.journey = journey
        self.destination = destination
        self.source = source
        self.planningPolicy = planningPolicy
    }
}

/// Resolves the one precedence rule shared by journey surfaces.
///
/// The order is deliberate: a running journey wins over a reminder, a
/// reminder wins over a planned draft, and the current search is the fallback.
/// Keeping the arbitration here makes the rule a small table-testable module.
enum JourneyContextResolver {
    static func resolve(
        journeyID: JourneyID,
        active: JourneyContext?,
        reminder: JourneyContext?,
        planned: JourneyContext?,
        search: JourneyContext?
    ) -> JourneyContext? {
        [active, reminder, planned, search]
            .compactMap { $0 }
            .first { $0.journey.id == journeyID }
    }
}
