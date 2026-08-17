import Foundation
import FoundationModels

@Generable(description: "Liste exhaustive des faits mentionnés dans la réponse")
struct GeneratedAnswerClaims {
    @Guide(description: "Tous les noms de lieux mentionnés, copiés exactement")
    var places: [String]

    @Guide(description: "Tous les noms courts de lignes mentionnés, copiés exactement")
    var lines: [String]

    @Guide(description: "Toutes les heures mentionnées, en ISO 8601 avec décalage")
    var times: [String]

    @Guide(description: "Toutes les durées mentionnées, en secondes")
    var durationsSeconds: [Int]

    @Guide(description: "Tous les avertissements mentionnés, copiés exactement")
    var warnings: [String]

    init(
        places: [String],
        lines: [String],
        times: [String],
        durationsSeconds: [Int],
        warnings: [String]
    ) {
        self.places = places
        self.lines = lines
        self.times = times
        self.durationsSeconds = durationsSeconds
        self.warnings = warnings
    }
}

@Generable(description: "Réponse de trajet courte accompagnée de ses faits vérifiables")
struct GeneratedVerifiedAnswer {
    @Guide(description: "Réponse française sans Markdown, en deux phrases et 240 caractères maximum")
    var answer: String
    var claims: GeneratedAnswerClaims

    init(answer: String, claims: GeneratedAnswerClaims) {
        self.answer = answer
        self.claims = claims
    }
}

enum OnDeviceAnswerComposer {
    private static let paris = TimeZone(identifier: "Europe/Paris")!
    private static let french = Locale(identifier: "fr_FR")

    static func deterministicAnswer(_ facts: OnDeviceAnswerFacts) -> String {
        "De \(facts.originLabel) à \(facts.destinationLabel) : départ "
            + "\(parisTime(facts.journey.departureAt)), arrivée "
            + "\(parisTime(facts.journey.arrivalAt)) le "
            + "\(parisLongDate(facts.journey.arrivalAt))."
    }

    static func validatedAnswer(
        _ output: GeneratedVerifiedAnswer,
        facts: OnDeviceAnswerFacts
    ) -> String? {
        guard validateAnswer(output, facts: facts) else { return nil }
        return output.answer.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func validateAnswer(
        _ output: GeneratedVerifiedAnswer,
        facts: OnDeviceAnswerFacts
    ) -> Bool {
        let answer = output.answer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !answer.isEmpty, answer.count <= 240 else { return false }
        let claims = output.claims
        guard
            claims.places.count <= 12,
            claims.lines.count <= 8,
            claims.times.count <= 6,
            claims.durationsSeconds.count <= 6,
            claims.warnings.count <= 6
        else { return false }

        let allowedLines = Set(facts.journey.sections.compactMap { section in
            section.kind == .transit ? section.route?.shortName : nil
        })
        let allowedPlaces = Set(
            [facts.originLabel, facts.destinationLabel]
                + facts.journey.sections.flatMap { [$0.from.name, $0.to.name] }
        )
        let allowedInstants = Set(
            [facts.journey.departureAt, facts.journey.arrivalAt, facts.requestedAt]
                + facts.journey.sections.flatMap { [$0.departureAt, $0.arrivalAt].compactMap { $0 } }
        ).map(ISO8601.string)
        let allowedDurations = Set(
            [facts.journey.durationSeconds]
                + facts.journey.sections.map(\.durationSeconds)
        )
        let allowedWarnings = Set(facts.journey.warnings)

        guard claims.places.allSatisfy(allowedPlaces.contains) else { return false }
        guard claims.lines.allSatisfy(allowedLines.contains) else { return false }
        guard claims.times.allSatisfy(Set(allowedInstants).contains) else { return false }
        guard claims.durationsSeconds.allSatisfy(allowedDurations.contains) else { return false }
        guard claims.warnings.allSatisfy(allowedWarnings.contains) else { return false }

        if answer.range(
            of: "perturb|interromp|incident|retard",
            options: [.regularExpression, .caseInsensitive]
        ) != nil, claims.warnings.isEmpty {
            return false
        }

        let mentionedLines = captures(
            in: answer,
            pattern: "(?:ligne|métro|RER|Transilien|tram|bus)\\s+([A-Z]?\\d*[A-Z]?)",
            capture: 1
        ).filter { !$0.isEmpty }
        guard mentionedLines.allSatisfy(allowedLines.contains) else { return false }

        let allowedTimes = Set([
            parisTime(facts.journey.departureAt, separator: "h"),
            parisTime(facts.journey.arrivalAt, separator: "h"),
            parisTime(facts.requestedAt, separator: "h"),
        ])
        let mentionedTimes = captures(
            in: answer,
            pattern: "\\b(?:[01]?\\d|2[0-3])\\s*(?:h|:)\\s*[0-5]\\d\\b",
            capture: 0
        )
        return mentionedTimes.allSatisfy { allowedTimes.contains(normalizeTime($0)) }
    }

    static func prompt(_ facts: OnDeviceAnswerFacts) -> String {
        let sections = facts.journey.sections.map { section in
            let line = section.route?.shortName ?? "aucune"
            return "\(section.kind.rawValue): \(section.from.name) → \(section.to.name), ligne \(line), durée \(section.durationSeconds) s"
        }.joined(separator: "\n")
        return """
        origine: \(facts.originLabel)
        destination: \(facts.destinationLabel)
        heure demandée: \(ISO8601.string(facts.requestedAt))
        sens: \(facts.datetimeRepresents.rawValue)
        départ: \(ISO8601.string(facts.journey.departureAt))
        arrivée: \(ISO8601.string(facts.journey.arrivalAt))
        durée: \(facts.journey.durationSeconds) s
        correspondances: \(facts.journey.transferCount)
        sections:
        \(sections)
        avertissements: \(facts.journey.warnings.joined(separator: " | "))
        préférence: \(facts.preferenceNotice ?? "aucune")
        """
    }

    private static func parisTime(_ date: Date, separator: String = " h ") -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = paris
        let components = calendar.dateComponents([.hour, .minute], from: date)
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0
        return "\(hour)\(separator)\(String(format: "%02d", minute))"
    }

    private static func parisLongDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = french
        formatter.timeZone = paris
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "EEEE d MMMM"
        return formatter.string(from: date)
    }

    private static func normalizeTime(_ value: String) -> String {
        let compact = value.lowercased().replacingOccurrences(
            of: "\\s",
            with: "",
            options: .regularExpression
        )
        let pieces = compact.split(whereSeparator: { $0 == "h" || $0 == ":" })
        guard pieces.count == 2 else { return compact }
        return "\(String(pieces[0]).leftPadded(to: 2))h\(pieces[1])"
    }

    private static func captures(
        in value: String,
        pattern: String,
        capture: Int
    ) -> [String] {
        guard let expression = try? NSRegularExpression(
            pattern: pattern,
            options: [.caseInsensitive]
        ) else { return [] }
        let range = NSRange(value.startIndex..., in: value)
        return expression.matches(in: value, range: range).compactMap { match in
            guard capture < match.numberOfRanges,
                  let range = Range(match.range(at: capture), in: value) else { return nil }
            return String(value[range])
        }
    }
}

private extension String {
    func leftPadded(to length: Int) -> String {
        String(repeating: "0", count: max(0, length - count)) + self
    }
}
