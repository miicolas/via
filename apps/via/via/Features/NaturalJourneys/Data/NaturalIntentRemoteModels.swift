import Foundation

enum NaturalIntentResponseDTO: Decodable {
    case interpreted(InterpretationDTO)
    case unavailable(String)

    struct PlaceDTO: Decodable {
        let kind: String
        let value: String
        let evidence: String
    }

    struct TimeDTO: Decodable {
        let reference: String
        let year: Int
        let yearWasExplicit: Bool
        let month: Int
        let day: Int
        let timePrecision: String
        let hour: Int
        let minute: Int
        let relativeAmount: Int
        let relativeUnit: String
        let meaning: String
        let evidence: String
    }

    struct LineStatusDTO: Decodable {
        let kind: String
        let code: String
        let mode: String
        let evidence: String
    }

    struct InterpretationDTO: Decodable {
        let scope: String
        let origin: PlaceDTO?
        let destination: PlaceDTO?
        let originWasExplicit: Bool
        let lastServiceOfDay: Bool
        let timeConstraint: TimeDTO
        let alternateTimeConstraint: TimeDTO?
        let requiredModes: [String]
        let excludedModes: [String]
        let preferredModes: [String]
        let unsupportedConstraints: [String]
        let unexplainedText: String
        let lineStatus: LineStatusDTO?
    }

    private enum CodingKeys: String, CodingKey { case outcome, interpretation, message }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(String.self, forKey: .outcome) {
        case "interpreted":
            self = .interpreted(try container.decode(
                InterpretationDTO.self,
                forKey: .interpretation,
            ))
        case "unavailable":
            self = .unavailable(try container.decode(String.self, forKey: .message))
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .outcome,
                in: container,
                debugDescription: "Unknown natural-journey interpretation outcome",
            )
        }
    }

    func proposal(
        for request: NaturalIntentModelRequest
    ) throws(NaturalIntentParsingError) -> NaturalIntentProposal {
        guard case .interpreted(let dto) = self else { throw .remoteUnavailable }
        guard ["journey", "line_status", "unsupported"].contains(dto.scope),
              dto.requiredModes.count <= 3,
              dto.excludedModes.count <= 3,
              dto.preferredModes.count <= 3,
              dto.unsupportedConstraints.count <= 3
        else {
            throw .invalidResponse
        }

        let lineStatus = try Self.lineStatus(dto, request: request)

        let originPlace: RoutePlaceIntent
        let originEvidence: String?
        if let origin = dto.origin {
            originPlace = try Self.place(
                origin,
                request: request,
                allowsCurrentLocation: true,
                expectedAnchor: request.originAnchor,
            )
            originEvidence = origin.evidence.nilIfBlank
        } else {
            originPlace = .currentLocation
            originEvidence = nil
        }
        switch originPlace {
        case .currentLocation:
            guard dto.originWasExplicit == (originEvidence != nil) else {
                throw .invalidResponse
            }
        case .query, .saved, .reference:
            guard dto.originWasExplicit else { throw .invalidResponse }
        }
        let destinationPlace: RoutePlaceIntent?
        if let destination = dto.destination {
            destinationPlace = try Self.place(
                destination,
                request: request,
                allowsCurrentLocation: false,
                expectedAnchor: request.destinationAnchor,
            )
        } else {
            destinationPlace = nil
        }
        let destinationEvidence = dto.destination?.evidence.nilIfBlank

        let primary = try dto.timeConstraint.domain(now: request.now, phrase: request.phrase)
        let alternate: (resolved: ResolvedNaturalDateTime, meaning: RouteIntent.TimeMeaning)?
        if let alternateTimeConstraint = dto.alternateTimeConstraint {
            alternate = try alternateTimeConstraint.domain(now: request.now, phrase: request.phrase)
        } else {
            alternate = nil
        }
        let unsupported = dto.unsupportedConstraints.map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard unsupported.allSatisfy({ !$0.isEmpty && $0.count <= 160 }) else {
            throw .invalidResponse
        }
        let residue = dto.unexplainedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard residue.isEmpty || Self.isEvidence(residue, in: request.phrase) else {
            throw .invalidResponse
        }

        let scope: RouteIntent.Scope = switch dto.scope {
        case "journey": .journey
        case "line_status": .lineStatus
        case "unsupported": .unsupported
        default: throw .invalidResponse
        }
        let intent = RouteIntent(
            scope: scope,
            originPlace: originPlace,
            destinationPlace: destinationPlace,
            requestedAt: primary.resolved.date,
            datetimeRepresents: primary.meaning,
            timeAnchor: dto.lastServiceOfDay ? .lastOfDay : nil,
            requiredModes: try Self.modes(dto.requiredModes),
            excludedModes: try Self.modes(dto.excludedModes),
            preferredModes: try Self.modes(dto.preferredModes),
            unsupportedConstraints: unsupported,
            dateWasExplicit: primary.resolved.dateWasExplicit,
            timeWasExplicit: primary.resolved.timeWasExplicit,
            alternateTimeConstraint: alternate.map {
                RouteTimeConstraint(
                    requestedAt: $0.resolved.date,
                    meaning: $0.meaning.journeyMeaning,
                )
            },
            originWasExplicit: dto.originWasExplicit,
            lineStatus: lineStatus,
        )
        return try NaturalIntentProposal(
            intent: intent,
            originEvidence: originEvidence,
            destinationEvidence: destinationEvidence,
            timeEvidence: dto.timeConstraint.evidence.nilIfBlank,
            unexplainedText: residue.nilIfBlank,
        ).validatingGrounding(in: request.phrase)
    }

    private static func place(
        _ dto: PlaceDTO,
        request: NaturalIntentModelRequest,
        allowsCurrentLocation: Bool,
        expectedAnchor: NaturalIntentModelAnchor?,
    ) throws(NaturalIntentParsingError) -> RoutePlaceIntent {
        switch dto.kind {
        case "current_location":
            guard allowsCurrentLocation, dto.value.isEmpty else { throw .invalidResponse }
            if !dto.evidence.isEmpty, !isEvidence(dto.evidence, in: request.phrase) {
                throw .invalidResponse
            }
            if !dto.evidence.isEmpty {
                let normalized = OnDevicePlaceResolver.normalize(dto.evidence)
                guard [
                    "ma position", "position actuelle", "ici", "d ici",
                    "my location", "current location", "here",
                ].contains(normalized) else { throw .invalidResponse }
            }
            return .currentLocation
        case "query":
            let query = dto.value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !query.isEmpty,
                  query.count <= 160,
                  isEvidence(dto.evidence, in: request.phrase)
            else {
                throw .invalidResponse
            }
            let normalizedQuery = OnDevicePlaceResolver.normalize(query)
            let normalizedEvidence = OnDevicePlaceResolver.normalize(dto.evidence)
            guard normalizedEvidence.contains(normalizedQuery) else {
                throw .invalidResponse
            }
            return .query(query)
        case "saved":
            guard let place = request.savedPlaces.first(where: { $0.id == dto.value }),
                  isEvidence(dto.evidence, in: request.phrase)
            else {
                throw .invalidResponse
            }
            return .saved(place)
        case "context_reference":
            guard let reference = NaturalJourneyConversationReference(rawValue: dto.value),
                  let expectedAnchor,
                  case .reference(let anchoredReference) = expectedAnchor.place,
                  anchoredReference == reference,
                  isEvidence(dto.evidence, in: request.phrase)
            else {
                throw .invalidResponse
            }
            return .reference(reference)
        default:
            throw .invalidResponse
        }
    }

    private static func modes(
        _ values: [String]
    ) throws(NaturalIntentParsingError) -> Set<TransitMode> {
        var modes: Set<TransitMode> = []
        for value in values {
            guard let mode = TransitMode(rawValue: value) else { throw .invalidResponse }
            modes.insert(mode)
        }
        return modes
    }

    private static func lineStatus(
        _ dto: InterpretationDTO,
        request: NaturalIntentModelRequest,
    ) throws(NaturalIntentParsingError) -> NaturalLineStatusIntent? {
        guard dto.scope == "line_status" else {
            guard dto.lineStatus == nil else { throw .invalidResponse }
            return nil
        }
        guard let line = dto.lineStatus,
              dto.origin == nil,
              dto.destination == nil,
              !dto.originWasExplicit,
              !dto.lastServiceOfDay,
              dto.requiredModes.isEmpty,
              dto.excludedModes.isEmpty,
              dto.preferredModes.isEmpty,
              dto.unsupportedConstraints.isEmpty,
              dto.timeConstraint.reference == "implicit_today",
              !dto.timeConstraint.yearWasExplicit,
              dto.timeConstraint.timePrecision == "unspecified",
              dto.timeConstraint.relativeAmount == 0,
              dto.timeConstraint.meaning == "departure",
              dto.timeConstraint.evidence.isEmpty,
              dto.alternateTimeConstraint == nil,
              isEvidence(line.evidence, in: request.phrase),
              let kind = NaturalLineStatusIntent.Kind(rawValue: line.kind)
        else {
            throw .invalidResponse
        }

        let mode: TransitMode?
        if line.mode == "any" {
            mode = nil
        } else if let parsed = TransitMode(rawValue: line.mode) {
            let evidence = OnDevicePlaceResolver.normalize(line.evidence)
            guard evidence.contains(line.mode)
                    || (parsed == .transilien && evidence.contains("train"))
            else { throw .invalidResponse }
            mode = parsed
        } else {
            throw .invalidResponse
        }

        let code = line.code.trimmingCharacters(in: .whitespacesAndNewlines)
        switch kind {
        case .specific:
            guard !code.isEmpty,
                  code.count <= 12,
                  containsLineCode(code, in: line.evidence)
            else { throw .invalidResponse }
        case .networkOverview, .disruptions:
            guard code.isEmpty else { throw .invalidResponse }
        }
        return NaturalLineStatusIntent(
            kind: kind,
            code: code,
            mode: mode,
            evidence: line.evidence,
        )
    }

    private static func containsLineCode(_ code: String, in evidence: String) -> Bool {
        let escaped = NSRegularExpression.escapedPattern(
            for: OnDevicePlaceResolver.normalize(code)
        )
        guard let expression = try? NSRegularExpression(
            pattern: "(^|[^a-z0-9])\(escaped)([^a-z0-9]|$)",
            options: [.caseInsensitive],
        ) else { return false }
        let normalized = OnDevicePlaceResolver.normalize(evidence)
        return expression.firstMatch(
            in: normalized,
            range: NSRange(normalized.startIndex..., in: normalized),
        ) != nil
    }

    private static func isEvidence(_ evidence: String, in phrase: String) -> Bool {
        let trimmed = evidence.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 200 else { return false }
        return phrase.range(
            of: trimmed,
            options: [.caseInsensitive, .diacriticInsensitive],
        ) != nil
    }
}

private extension NaturalIntentResponseDTO.TimeDTO {
    func domain(
        now: Date,
        phrase: String,
    ) throws(NaturalIntentParsingError) -> (
        resolved: ResolvedNaturalDateTime,
        meaning: RouteIntent.TimeMeaning
    ) {
        let parts = try NaturalDateTimeParts(
            reference: try reference.domainDateReference,
            year: year,
            yearWasExplicit: yearWasExplicit,
            month: month,
            day: day,
            timePrecision: try timePrecision.domainTimePrecision,
            hour: hour,
            minute: minute,
            relativeAmount: relativeAmount,
            relativeUnit: try relativeUnit.domainRelativeUnit,
        ).validatingExplicitTime(in: evidence)
        let resolved: ResolvedNaturalDateTime
        do {
            resolved = try NaturalDateTimeResolver.resolve(parts, now: now)
        } catch {
            throw .invalidResponse
        }
        let meaning: RouteIntent.TimeMeaning = switch self.meaning {
        case "departure": .departure
        case "arrival": .arrival
        case "ambiguous": .ambiguous
        default: throw .invalidResponse
        }
        let requiresEvidence = resolved.dateWasExplicit || resolved.timeWasExplicit
        if requiresEvidence && evidence.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw .invalidResponse
        }
        if !evidence.isEmpty,
           phrase.range(
               of: evidence,
               options: [.caseInsensitive, .diacriticInsensitive],
           ) == nil
        {
            throw .invalidResponse
        }
        return (resolved, meaning)
    }
}

private extension String {
    var domainDateReference: NaturalDateReference {
        get throws(NaturalIntentParsingError) {
            switch self {
            case "implicit_today": .implicitToday
            case "today": .today
            case "tomorrow": .tomorrow
            case "monday": .monday
            case "tuesday": .tuesday
            case "wednesday": .wednesday
            case "thursday": .thursday
            case "friday": .friday
            case "saturday": .saturday
            case "sunday": .sunday
            case "calendar_date": .calendarDate
            case "relative": .relative
            default: throw .invalidResponse
            }
        }
    }

    var domainTimePrecision: NaturalTimePrecision {
        get throws(NaturalIntentParsingError) {
            switch self {
            case "unspecified": .unspecified
            case "exact": .exact
            case "morning": .morning
            case "afternoon": .afternoon
            case "evening": .evening
            default: throw .invalidResponse
            }
        }
    }

    var domainRelativeUnit: NaturalRelativeUnit {
        get throws(NaturalIntentParsingError) {
            switch self {
            case "minute": .minute
            case "hour": .hour
            case "day": .day
            default: throw .invalidResponse
            }
        }
    }

    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
