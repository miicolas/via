import Foundation

struct ActiveJourneyContext: Sendable, Hashable {
    let journeyID: JourneyID
    let lineID: RouteID?
    let vehicleID: String?
}

protocol ActiveJourneyProvider: Sendable {
    func activeJourney() async -> ActiveJourneyContext?
}

struct NoActiveJourneyProvider: ActiveJourneyProvider {
    func activeJourney() async -> ActiveJourneyContext? { nil }
}
