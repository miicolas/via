import Foundation

enum RouteOriginIntent: Sendable, Hashable {
    case currentLocation
    case place(query: String)
}

struct RouteIntent: Sendable, Hashable {
    enum Scope: String, Sendable, Hashable { case journey, unsupported }
    enum TimeMeaning: String, Sendable, Hashable { case departure, arrival, ambiguous }

    let scope: Scope
    let origin: RouteOriginIntent
    let destinationQuery: String?
    let requestedAt: Date?
    let datetimeRepresents: TimeMeaning
    let requiredModes: Set<TransitMode>
    let excludedModes: Set<TransitMode>
    let preferredModes: Set<TransitMode>
}

struct NaturalJourneyDraft: Sendable, Hashable {
    let intent: RouteIntent
    let origin: SearchResult?
    let destination: SearchResult?
}

enum NaturalJourneyRequest: Sendable, Hashable {
    case submit(query: String, currentLocation: GeoCoordinate?)
    case resolve(
        draft: NaturalJourneyDraft,
        currentLocation: GeoCoordinate?,
        origin: SearchResult?,
        destination: SearchResult?,
        datetimeRepresents: JourneyDatetimeRepresents?
    )
}

struct NaturalJourneyInterpretation: Sendable, Hashable {
    let originLabel: String
    let destination: JourneyDestination
    let destinationResult: SearchResult
    let requestedAt: Date
    let datetimeRepresents: JourneyDatetimeRepresents
    let requiredModes: Set<TransitMode>
    let excludedModes: Set<TransitMode>
    let preferredModes: Set<TransitMode>
}

struct NaturalJourneyClarification: Sendable, Hashable, Identifiable {
    enum Target: String, Sendable, Hashable { case origin, destination, time }

    let target: Target
    let question: String
    let candidates: [SearchResult]

    var id: Target { target }
}

enum NaturalJourneyResult: Sendable, Hashable {
    case ready(
        answer: String,
        preferenceNotice: String?,
        interpretation: NaturalJourneyInterpretation,
        journeys: JourneyResult
    )
    case needsClarification(draft: NaturalJourneyDraft, fields: [NaturalJourneyClarification])
    case unsupported(message: String, examples: [String])
    case unavailable(message: String)
    case rateLimited(message: String)
}

