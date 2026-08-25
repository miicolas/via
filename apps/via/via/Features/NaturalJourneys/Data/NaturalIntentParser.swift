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

struct NaturalIntentModelAnchor: Sendable, Hashable {
    let place: RoutePlaceIntent
    let evidence: String
}

struct NaturalIntentModelRequest: Sendable, Hashable {
    let phrase: String
    let locale: Locale
    let now: Date
    let hasCurrentLocation: Bool
    let originAnchor: NaturalIntentModelAnchor?
    let destinationAnchor: NaturalIntentModelAnchor?
    let savedPlaces: [NaturalJourneySavedPlaceReference]
}

struct NaturalIntentProposal: Sendable, Hashable {
    let intent: RouteIntent
    let originEvidence: String?
    let destinationEvidence: String?
    let timeEvidence: String?
    let unexplainedText: String?

    init(
        intent: RouteIntent,
        originEvidence: String? = nil,
        destinationEvidence: String? = nil,
        timeEvidence: String? = nil,
        unexplainedText: String? = nil,
    ) {
        self.intent = intent
        self.originEvidence = originEvidence
        self.destinationEvidence = destinationEvidence
        self.timeEvidence = timeEvidence
        self.unexplainedText = unexplainedText
    }

    /// Foundation Models' generated schema still expresses a place as text.
    /// Rehydrate a semantically identical locked anchor to its canonical type
    /// before merging; a genuinely different value is deliberately preserved
    /// so the validator can surface the disagreement.
    func reconcilingLockedAnchors(
        in request: NaturalIntentModelRequest
    ) -> Self {
        var reconciled = intent
        if let anchor = request.originAnchor,
           Self.matches(intent.originPlace, anchor: anchor)
        {
            reconciled = reconciled.replacingPlaces(origin: anchor.place)
        }
        if let anchor = request.destinationAnchor,
           let destination = intent.destinationPlace,
           Self.matches(destination, anchor: anchor)
        {
            reconciled = reconciled.replacingPlaces(
                destination: anchor.place,
                replaceDestination: true,
            )
        }
        return Self(
            intent: reconciled,
            originEvidence: request.originAnchor?.evidence ?? originEvidence,
            destinationEvidence: request.destinationAnchor?.evidence ?? destinationEvidence,
            timeEvidence: timeEvidence,
            unexplainedText: unexplainedText,
        )
    }

    func validatingGrounding(
        in phrase: String
    ) throws(NaturalIntentParsingError) -> Self {
        if intent.dateWasExplicit || intent.timeWasExplicit {
            guard let timeEvidence,
                  Self.isExactFragment(timeEvidence, of: phrase)
            else { throw .invalidResponse }
        } else if let timeEvidence,
                  !Self.isExactFragment(timeEvidence, of: phrase)
        {
            throw .invalidResponse
        }
        if intent.timeAnchor != nil {
            let normalized = OnDevicePlaceResolver.normalize(phrase)
            guard normalized.contains("dernier") || normalized.contains("last") else {
                throw .invalidResponse
            }
        }

        let normalizedPhrase = OnDevicePlaceResolver.normalize(phrase)
        let modes = intent.requiredModes
            .union(intent.excludedModes)
            .union(intent.preferredModes)
        guard modes.allSatisfy({ normalizedPhrase.contains($0.naturalLanguageToken) }) else {
            throw .invalidResponse
        }
        guard intent.unsupportedConstraints.allSatisfy({
            Self.isExactFragment($0, of: phrase)
        }) else {
            throw .invalidResponse
        }
        return self
    }

    private static func matches(
        _ proposed: RoutePlaceIntent,
        anchor: NaturalIntentModelAnchor,
    ) -> Bool {
        switch (proposed, anchor.place) {
        case (.currentLocation, .currentLocation):
            true
        case let (.query(proposed), .query(locked)):
            equivalent(proposed, to: locked)
        case let (.saved(proposed), .saved(locked)):
            proposed.id == locked.id
        case let (.query(proposed), .saved(locked)):
            equivalent(proposed, to: locked.label)
                || equivalent(proposed, to: anchor.evidence)
        case let (.reference(proposed), .reference(locked)):
            proposed == locked
        case let (.query(proposed), .reference(locked)):
            proposedReference(proposed, evidence: anchor.evidence) == locked
        default:
            false
        }
    }

    private static func equivalent(_ lhs: String, to rhs: String) -> Bool {
        let left = OnDevicePlaceResolver.normalize(lhs)
        let right = OnDevicePlaceResolver.normalize(rhs)
        return left == right || left.contains(right) || right.contains(left)
    }

    private static func proposedReference(
        _ value: String,
        evidence: String
    ) -> NaturalJourneyConversationReference? {
        let candidates = [value, evidence].map(OnDevicePlaceResolver.normalize)
        if candidates.contains(where: {
            ["same origin", "same departure", "meme origine", "meme depart"].contains($0)
        }) {
            return .previousOrigin
        }
        if candidates.contains(where: {
            ["same destination", "meme destination"].contains($0)
        }) {
            return .previousDestination
        }
        if candidates.contains(where: {
            ["there", "same place", "y", "la", "la bas", "meme endroit"].contains($0)
        }) {
            return .uniquelyConfirmedPlace
        }
        return nil
    }

    private static func isExactFragment(_ fragment: String, of phrase: String) -> Bool {
        let value = fragment.trimmingCharacters(in: .whitespacesAndNewlines)
        return !value.isEmpty && phrase.range(
            of: value,
            options: [.caseInsensitive, .diacriticInsensitive],
        ) != nil
    }
}

private extension TransitMode {
    var naturalLanguageToken: String {
        switch self {
        case .metro: "metro"
        case .rer: "rer"
        case .transilien: "transilien"
        case .tram: "tram"
        case .bus: "bus"
        }
    }
}

protocol NaturalIntentParsing: Sendable {
    var availability: NaturalLanguageAvailability { get }

    func proposeIntent(
        _ request: NaturalIntentModelRequest
    ) async throws(NaturalIntentParsingError) -> NaturalIntentProposal
}

extension NaturalIntentParsing {
    func parseIntent(
        _ phrase: String,
        now: Date
    ) async throws(NaturalIntentParsingError) -> RouteIntent {
        let turn = NaturalJourneyTurn(phrase: phrase, now: now)
        return try await proposeIntent(NaturalIntentModelRequest(
            phrase: phrase,
            locale: turn.locale,
            now: now,
            hasCurrentLocation: false,
            originAnchor: nil,
            destinationAnchor: nil,
            savedPlaces: [],
        )).intent
    }
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
    func proposeIntent(
        _: NaturalIntentModelRequest
    ) async throws(NaturalIntentParsingError) -> NaturalIntentProposal {
        if let parsingError { throw parsingError }
        return NaturalIntentProposal(intent: intent)
    }
}
