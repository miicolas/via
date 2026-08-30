/// Where the natural-language conversation stands, from the composer's
/// resting state to the question or answer currently on screen.
enum NaturalSearchState: Sendable, Hashable {
    case dismissed
    case onboarding
    case input
    case loading
    case clarification(draft: NaturalJourneyDraft, field: NaturalJourneyClarification)
    case decision(draft: NaturalJourneyDraft, decision: NaturalJourneyDecision)
    case unsupported(message: String, examples: [String])
    case availability(NaturalJourneyUnavailableGuidance)
    case failed(message: String)
}
