import Foundation

struct RouteIntentDTO: Codable {
    enum OriginDTO: Codable {
        case currentLocation
        case place(String)

        private enum CodingKeys: String, CodingKey { case kind, query }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            switch try container.decode(String.self, forKey: .kind) {
            case "current_location": self = .currentLocation
            case "place": self = .place(try container.decode(String.self, forKey: .query))
            default:
                throw DecodingError.dataCorruptedError(
                    forKey: .kind,
                    in: container,
                    debugDescription: "Unknown origin"
                )
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .currentLocation:
                try container.encode("current_location", forKey: .kind)
            case .place(let query):
                try container.encode("place", forKey: .kind)
                try container.encode(query, forKey: .query)
            }
        }
    }

    let scope: String
    let origin: OriginDTO
    let destinationQuery: String?
    let requestedAt: Date?
    let datetimeRepresents: String
    let requiredModes: [String]
    let excludedModes: [String]
    let preferredModes: [String]

    init(_ value: RouteIntent) {
        let origin: OriginDTO = switch value.origin {
        case .currentLocation: .currentLocation
        case .place(let query): .place(query)
        }
        scope = value.scope.rawValue
        self.origin = origin
        destinationQuery = value.destinationQuery
        requestedAt = value.requestedAt
        datetimeRepresents = value.datetimeRepresents.rawValue
        requiredModes = value.requiredModes.map(\.rawValue).sorted()
        excludedModes = value.excludedModes.map(\.rawValue).sorted()
        preferredModes = value.preferredModes.map(\.rawValue).sorted()
    }

    func domain() throws -> RouteIntent {
        guard
            let scope = RouteIntent.Scope(rawValue: scope),
            let time = RouteIntent.TimeMeaning(rawValue: datetimeRepresents)
        else { throw ViaError.decoding }
        let mappedOrigin: RouteOriginIntent = switch origin {
        case .currentLocation: .currentLocation
        case .place(let query): .place(query: query)
        }
        return RouteIntent(
            scope: scope,
            origin: mappedOrigin,
            destinationQuery: destinationQuery,
            requestedAt: requestedAt,
            datetimeRepresents: time,
            requiredModes: Set(requiredModes.compactMap(TransitMode.init(rawValue:))),
            excludedModes: Set(excludedModes.compactMap(TransitMode.init(rawValue:))),
            preferredModes: Set(preferredModes.compactMap(TransitMode.init(rawValue:)))
        )
    }
}

struct NaturalJourneyDraftDTO: Codable {
    let intent: RouteIntentDTO
    let origin: SearchResultDTO?
    let destination: SearchResultDTO?

    init(_ value: NaturalJourneyDraft) {
        intent = .init(value.intent)
        origin = value.origin.map(SearchResultDTO.init)
        destination = value.destination.map(SearchResultDTO.init)
    }

    func domain() throws -> NaturalJourneyDraft {
        NaturalJourneyDraft(
            intent: try intent.domain(),
            origin: try origin?.domain(),
            destination: try destination?.domain()
        )
    }
}

enum NaturalJourneyRequestDTO: Encodable {
    case submit(query: String, location: CoordinateDTO?)
    case resolve(
        draft: NaturalJourneyDraftDTO,
        location: CoordinateDTO?,
        origin: SearchResultDTO?,
        destination: SearchResultDTO?,
        time: String?
    )

    private enum CodingKeys: String, CodingKey {
        case action, query, currentLocation, draft, origin, destination, datetimeRepresents
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .submit(let query, let location):
            try container.encode("submit", forKey: .action)
            try container.encode(query, forKey: .query)
            try container.encodeIfPresent(location, forKey: .currentLocation)
        case .resolve(let draft, let location, let origin, let destination, let time):
            try container.encode("resolve", forKey: .action)
            try container.encode(draft, forKey: .draft)
            try container.encodeIfPresent(location, forKey: .currentLocation)
            try container.encodeIfPresent(origin, forKey: .origin)
            try container.encodeIfPresent(destination, forKey: .destination)
            try container.encodeIfPresent(time, forKey: .datetimeRepresents)
        }
    }
}

enum NaturalJourneyResultDTO: Decodable {
    struct Ready: Decodable {
        struct Interpretation: Decodable {
            let originLabel: String
            let destination: JourneyDestinationDTO
            let destinationResult: SearchResultDTO
            let requestedAt: Date
            let datetimeRepresents: String
            let requiredModes: [String]
            let excludedModes: [String]
            let preferredModes: [String]
        }

        let answer: String
        let preferenceNotice: String?
        let interpretation: Interpretation
        let journeys: JourneyResultDTO
    }

    struct Clarification: Decodable {
        struct Field: Decodable {
            let target: String
            let question: String
            let candidates: [SearchResultDTO]
        }

        let draft: NaturalJourneyDraftDTO
        let fields: [Field]
    }

    struct Message: Decodable {
        let message: String
        let examples: [String]?
    }

    case ready(Ready)
    case clarification(Clarification)
    case unsupported(Message)
    case unavailable(Message)
    case rateLimited(Message)

    private enum CodingKeys: String, CodingKey { case status }

    init(from decoder: Decoder) throws {
        let status = try decoder.container(keyedBy: CodingKeys.self).decode(
            String.self,
            forKey: .status
        )
        let single = try decoder.singleValueContainer()
        switch status {
        case "ready": self = .ready(try single.decode(Ready.self))
        case "needs_clarification": self = .clarification(try single.decode(Clarification.self))
        case "unsupported": self = .unsupported(try single.decode(Message.self))
        case "unavailable": self = .unavailable(try single.decode(Message.self))
        case "rate_limited": self = .rateLimited(try single.decode(Message.self))
        default:
            throw DecodingError.dataCorruptedError(
                in: single,
                debugDescription: "Unknown natural result: \(status)"
            )
        }
    }

    func domain() throws -> NaturalJourneyResult {
        switch self {
        case .ready(let value):
            let interpretation = value.interpretation
            guard let time = JourneyDatetimeRepresents(
                rawValue: interpretation.datetimeRepresents
            ) else { throw ViaError.decoding }
            return .ready(
                answer: value.answer,
                preferenceNotice: value.preferenceNotice,
                interpretation: NaturalJourneyInterpretation(
                    originLabel: interpretation.originLabel,
                    destination: interpretation.destination.domain,
                    destinationResult: try interpretation.destinationResult.domain(),
                    requestedAt: interpretation.requestedAt,
                    datetimeRepresents: time,
                    requiredModes: Set(
                        interpretation.requiredModes.compactMap(TransitMode.init(rawValue:))
                    ),
                    excludedModes: Set(
                        interpretation.excludedModes.compactMap(TransitMode.init(rawValue:))
                    ),
                    preferredModes: Set(
                        interpretation.preferredModes.compactMap(TransitMode.init(rawValue:))
                    )
                ),
                journeys: try value.journeys.domain()
            )
        case .clarification(let value):
            return .needsClarification(
                draft: try value.draft.domain(),
                fields: try value.fields.map { field in
                    guard let target = NaturalJourneyClarification.Target(rawValue: field.target) else {
                        throw ViaError.decoding
                    }
                    return NaturalJourneyClarification(
                        target: target,
                        question: field.question,
                        candidates: try field.candidates.map { try $0.domain() }
                    )
                }
            )
        case .unsupported(let value):
            return .unsupported(message: value.message, examples: value.examples ?? [])
        case .unavailable(let value):
            return .unavailable(message: value.message)
        case .rateLimited(let value):
            return .rateLimited(message: value.message)
        }
    }
}
