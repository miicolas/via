import Foundation

enum NaturalJourneyDatetimeRepresents: String, Codable, Hashable, Sendable {
    case departure
    case arrival
    case ambiguous
}

enum NaturalJourneyOrigin: Codable, Hashable, Sendable {
    case currentLocation
    case place(query: String)

    private enum CodingKeys: String, CodingKey {
        case kind
        case query
    }

    private enum Kind: String, Codable {
        case currentLocation = "current_location"
        case place
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .kind) {
        case .currentLocation:
            self = .currentLocation
        case .place:
            self = .place(query: try container.decode(String.self, forKey: .query))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .currentLocation:
            try container.encode(Kind.currentLocation, forKey: .kind)
        case .place(let query):
            try container.encode(Kind.place, forKey: .kind)
            try container.encode(query, forKey: .query)
        }
    }
}

struct NaturalJourneyIntent: Codable, Hashable, Sendable {
    enum Scope: String, Codable, Hashable, Sendable {
        case journey
        case unsupported
    }

    let scope: Scope
    let origin: NaturalJourneyOrigin
    let destinationQuery: String?
    let requestedAt: String?
    let datetimeRepresents: NaturalJourneyDatetimeRepresents
    let requiredModes: [TransitMode]
    let excludedModes: [TransitMode]
    let preferredModes: [TransitMode]
}

struct NaturalJourneyDraft: Codable, Hashable, Sendable {
    let intent: NaturalJourneyIntent
    let origin: SearchResult?
    let destination: SearchResult?
}

enum NaturalJourneyRequest: Encodable, Hashable, Sendable {
    case submit(query: String, currentLocation: GeoCoordinate?)
    case resolve(
        draft: NaturalJourneyDraft,
        currentLocation: GeoCoordinate?,
        origin: SearchResult?,
        destination: SearchResult?,
        datetimeRepresents: NaturalJourneyDatetimeRepresents?
    )

    private enum CodingKeys: String, CodingKey {
        case action
        case query
        case draft
        case currentLocation
        case origin
        case destination
        case datetimeRepresents
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .submit(let query, let currentLocation):
            try container.encode("submit", forKey: .action)
            try container.encode(query, forKey: .query)
            try container.encodeIfPresent(currentLocation, forKey: .currentLocation)
        case .resolve(let draft, let currentLocation, let origin, let destination, let datetimeRepresents):
            try container.encode("resolve", forKey: .action)
            try container.encode(draft, forKey: .draft)
            try container.encodeIfPresent(currentLocation, forKey: .currentLocation)
            try container.encodeIfPresent(origin, forKey: .origin)
            try container.encodeIfPresent(destination, forKey: .destination)
            try container.encodeIfPresent(datetimeRepresents, forKey: .datetimeRepresents)
        }
    }
}

struct NaturalJourneyInterpretation: Decodable, Equatable, Sendable {
    let originLabel: String
    let destination: JourneyDestination
    let destinationResult: SearchResult
    let requestedAt: String
    let datetimeRepresents: NaturalJourneyDatetimeRepresents
    let requiredModes: [TransitMode]
    let excludedModes: [TransitMode]
    let preferredModes: [TransitMode]
}

struct NaturalJourneyReady: Decodable, Equatable, Sendable {
    enum AnswerSource: String, Decodable, Equatable, Sendable {
        case ai
        case deterministic
    }

    let answer: String
    let answerSource: AnswerSource
    let preferenceNotice: String?
    let interpretation: NaturalJourneyInterpretation
    let journeys: JourneysResponse
}

struct NaturalJourneyClarificationField: Decodable, Equatable, Identifiable, Sendable {
    enum Target: String, Decodable, Equatable, Sendable {
        case origin
        case destination
        case time
    }

    let target: Target
    let question: String
    let candidates: [SearchResult]

    var id: String { target.rawValue }
}

struct NaturalJourneyNeedsClarification: Decodable, Equatable, Sendable {
    let draft: NaturalJourneyDraft
    let fields: [NaturalJourneyClarificationField]
}

enum NaturalJourneyFailure: Equatable, Sendable {
    case unsupported(message: String, examples: [String])
    case unavailable(reason: Reason, message: String)
    case rateLimited(message: String)

    enum Reason: String, Decodable, Equatable, Sendable {
        case ai
        case geocoder
        case journey
        case dateOutOfRange = "date_out_of_range"
        case location
    }
}

enum NaturalJourneyResponse: Decodable, Equatable, Sendable {
    case ready(NaturalJourneyReady)
    case needsClarification(NaturalJourneyNeedsClarification)
    case failure(NaturalJourneyFailure)

    private enum CodingKeys: String, CodingKey {
        case status
        case answer
        case answerSource
        case preferenceNotice
        case interpretation
        case journeys
        case draft
        case fields
        case message
        case examples
        case reason
    }

    private enum Status: String, Decodable {
        case ready
        case needsClarification = "needs_clarification"
        case unsupported
        case unavailable
        case rateLimited = "rate_limited"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Status.self, forKey: .status) {
        case .ready:
            self = .ready(
                NaturalJourneyReady(
                    answer: try container.decode(String.self, forKey: .answer),
                    answerSource: try container.decode(NaturalJourneyReady.AnswerSource.self, forKey: .answerSource),
                    preferenceNotice: try container.decodeIfPresent(String.self, forKey: .preferenceNotice),
                    interpretation: try container.decode(NaturalJourneyInterpretation.self, forKey: .interpretation),
                    journeys: try container.decode(JourneysResponse.self, forKey: .journeys)
                )
            )
        case .needsClarification:
            self = .needsClarification(
                NaturalJourneyNeedsClarification(
                    draft: try container.decode(NaturalJourneyDraft.self, forKey: .draft),
                    fields: try container.decode([NaturalJourneyClarificationField].self, forKey: .fields)
                )
            )
        case .unsupported:
            self = .failure(
                .unsupported(
                    message: try container.decode(String.self, forKey: .message),
                    examples: try container.decode([String].self, forKey: .examples)
                )
            )
        case .unavailable:
            self = .failure(
                .unavailable(
                    reason: try container.decode(NaturalJourneyFailure.Reason.self, forKey: .reason),
                    message: try container.decode(String.self, forKey: .message)
                )
            )
        case .rateLimited:
            self = .failure(
                .rateLimited(message: try container.decode(String.self, forKey: .message))
            )
        }
    }
}
