import Foundation

struct ActiveJourneyContext: Sendable, Hashable {
    let journeyID: JourneyID
    let lineID: RouteID?
    let vehicleID: String?
}

protocol ActiveJourneyProvider: Sendable {
    @MainActor
    func activeJourney() async -> ActiveJourneyContext?
}

struct NoActiveJourneyProvider: ActiveJourneyProvider {
    @MainActor
    func activeJourney() async -> ActiveJourneyContext? { nil }
}
