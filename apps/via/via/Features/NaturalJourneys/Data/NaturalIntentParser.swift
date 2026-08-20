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

protocol NaturalIntentParsing: Sendable {
    var availability: NaturalLanguageAvailability { get }

    func parseIntent(
        _ phrase: String,
        now: Date
    ) async throws(NaturalIntentParsingError) -> RouteIntent
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
    func parseIntent(
        _: String,
        now _: Date
    ) async throws(NaturalIntentParsingError) -> RouteIntent {
        if let parsingError { throw parsingError }
        return intent
    }
}
