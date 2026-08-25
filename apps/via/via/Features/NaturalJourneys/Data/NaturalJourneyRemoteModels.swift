import Foundation

/// Wire shape of POST /natural-journeys, discriminated on `outcome`. The
/// server deliberately has no clarification or decision branches: everything
/// after a clarification flows through the on-device pipeline instead.
enum NaturalJourneyResponseDTO: Decodable {
    case ready(Ready)
    case unsupported(Unsupported)
    case unavailable(Unavailable)

    struct Ready: Decodable {
        let interpretation: InterpretationDTO
        let journeys: JourneyResultDTO
    }

    struct Unsupported: Decodable {
        let message: String
        let examples: [String]
    }

    struct Unavailable: Decodable {
        let message: String
    }

    struct InterpretationDTO: Decodable {
        let originLabel: String
        /// Absent when the origin is the device's current location.
        let origin: SearchResultDTO?
        let destination: JourneyDestinationDTO
        let destinationResult: SearchResultDTO
        let requestedAt: Date
        let datetimeRepresents: String
        /// Absent unless the phrase asked for the last service of the day.
        let timeAnchor: String?
        let requiredModes: [String]
        let excludedModes: [String]
        let preferredModes: [String]

        func domain() throws -> NaturalJourneyInterpretation {
            guard let represents = JourneyDatetimeRepresents(rawValue: datetimeRepresents) else {
                throw ViaError.decoding
            }
            let anchor = try timeAnchor.map { value in
                guard let anchor = JourneyTimeAnchor(rawValue: value) else {
                    throw ViaError.decoding
                }
                return anchor
            }
            return NaturalJourneyInterpretation(
                originLabel: originLabel,
                originResult: try origin?.domain(),
                destination: destination.domain,
                destinationResult: try destinationResult.domain(),
                requestedAt: requestedAt,
                datetimeRepresents: represents,
                timeAnchor: anchor,
                requiredModes: try Self.modes(requiredModes),
                excludedModes: try Self.modes(excludedModes),
                preferredModes: try Self.modes(preferredModes),
            )
        }

        private static func modes(_ values: [String]) throws -> Set<TransitMode> {
            Set(try values.map { value in
                guard let mode = TransitMode(rawValue: value) else { throw ViaError.decoding }
                return mode
            })
        }
    }

    private enum CodingKeys: String, CodingKey { case outcome }

    init(from decoder: Decoder) throws {
        let outcome = try decoder.container(keyedBy: CodingKeys.self).decode(
            String.self,
            forKey: .outcome
        )
        let single = try decoder.singleValueContainer()
        switch outcome {
        case "ready": self = .ready(try single.decode(Ready.self))
        case "unsupported": self = .unsupported(try single.decode(Unsupported.self))
        case "unavailable": self = .unavailable(try single.decode(Unavailable.self))
        default:
            throw DecodingError.dataCorruptedError(
                in: single,
                debugDescription: "Unknown outcome: \(outcome)"
            )
        }
    }

    func domain() throws -> NaturalJourneyResult {
        switch self {
        case .ready(let value):
            .ready(
                interpretation: try value.interpretation.domain(),
                journeys: try value.journeys.domain(),
            )
        case .unsupported(let value):
            .unsupported(message: value.message, examples: value.examples)
        case .unavailable(let value):
            .unavailable(message: value.message)
        }
    }
}
