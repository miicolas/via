import Foundation

enum NaturalIntentParsingError: Error, Sendable, Hashable {
    case cancelled
    case modelNotReady
    case unsupportedLanguage
    case modelBusy
    case contextWindowExceeded
    case contentRefused
    case invalidResponse
    case modelFailed
}

struct OnDeviceAnswerFacts: Sendable, Hashable {
    let originLabel: String
    let destinationLabel: String
    let requestedAt: Date
    let datetimeRepresents: JourneyDatetimeRepresents
    let journey: Journey
    let preferenceNotice: String?
}

protocol NaturalIntentParsing: Sendable {
    var availability: NaturalLanguageAvailability { get }

    func parseIntent(
        _ phrase: String,
        now: Date
    ) async throws(NaturalIntentParsingError) -> RouteIntent

    /// Returns `nil` whenever generation or fact validation cannot be trusted.
    /// Callers must then use the deterministic answer.
    func writeAnswer(_ facts: OnDeviceAnswerFacts) async -> String?
}

struct InMemoryNaturalIntentParser: NaturalIntentParsing {
    var availability: NaturalLanguageAvailability = .available
    var intent: RouteIntent = .init(
        scope: .unsupported,
        origin: .currentLocation,
        destinationQuery: nil,
        requestedAt: nil,
        datetimeRepresents: .departure,
        requiredModes: [],
        excludedModes: [],
        preferredModes: []
    )
    var parsingError: NaturalIntentParsingError?
    var answer: String?

    func parseIntent(
        _ phrase: String,
        now: Date
    ) async throws(NaturalIntentParsingError) -> RouteIntent {
        if let parsingError { throw parsingError }
        return intent
    }

    func writeAnswer(_ facts: OnDeviceAnswerFacts) async -> String? { answer }
}
