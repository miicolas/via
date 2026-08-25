import Foundation

extension NaturalDateTimeParts {
    func correctingSingleExactTime(in phrase: String) -> Self {
        guard reference != .relative,
              let time = ExplicitNaturalTimeSyntax.singleClockTime(in: phrase)
        else {
            return self
        }

        var corrected = self
        corrected.timePrecision = .exact
        corrected.hour = time.hour
        corrected.minute = time.minute
        return corrected
    }

    /// A structured shape is not proof that the temporal value was mentioned.
    /// Lock numeric clocks and relative durations back to their exact evidence
    /// before calendar math, rejecting values the model could have invented.
    func validatingExplicitTime(
        in evidence: String
    ) throws(NaturalIntentParsingError) -> Self {
        let normalized = OnDevicePlaceResolver.normalize(evidence)
        if reference == .relative {
            let unitTokens: [String] = switch relativeUnit {
            case .minute: ["minute", "minutes", "min"]
            case .hour: ["heure", "heures", "hour", "hours"]
            case .day: ["jour", "jours", "day", "days"]
            }
            guard relativeAmount > 0,
                  normalized.contains(String(relativeAmount)),
                  unitTokens.contains(where: normalized.contains)
            else { throw .invalidResponse }
            return self
        }

        let corrected = correctingSingleExactTime(in: evidence)
        if corrected.timePrecision == .exact,
           ExplicitNaturalTimeSyntax.singleClockTime(in: evidence) == nil
        {
            throw .invalidResponse
        }
        if corrected.yearWasExplicit,
           !normalized.contains(String(corrected.year))
        {
            throw .invalidResponse
        }
        return corrected
    }
}

private enum ExplicitNaturalTimeSyntax {
    // Compiled once: the alternation is long enough that rebuilding it would
    // dominate the match on every natural-language parse.
    private static let expression = try? NSRegularExpression(
        pattern: #"\b([01]?\d|2[0-3])\s*(?:h(?:eures?)?|:)\s*([0-5]\d)?\b"#,
        options: [.caseInsensitive]
    )

    static func singleClockTime(in phrase: String) -> (hour: Int, minute: Int)? {
        guard let expression else { return nil }

        let range = NSRange(phrase.startIndex..., in: phrase)
        let matches = expression.matches(in: phrase, range: range)
        guard matches.count == 1,
              let hourRange = Range(matches[0].range(at: 1), in: phrase),
              let hour = Int(phrase[hourRange])
        else {
            return nil
        }

        let minute = Range(matches[0].range(at: 2), in: phrase)
            .flatMap { Int(phrase[$0]) } ?? 0
        return (hour, minute)
    }
}
