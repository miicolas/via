import Foundation

extension NaturalDateTimeParts {
    func correctingSingleExactTime(in phrase: String) -> Self {
        guard reference != .relative,
              timePrecision != .exact,
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
}

private enum ExplicitNaturalTimeSyntax {
    // Compiled once: the alternation is long enough that rebuilding it would
    // dominate the match on every natural-language parse.
    private static let expression = try? NSRegularExpression(
        pattern:
            #"(?:après|apres|avant|vers|à\s+partir\s+de|a\s+partir\s+de|partir\s+[àa]|arriver\s+[àa]|être\s+[àa]|etre\s+[àa]|[àa])\s*([01]?\d|2[0-3])\s*(?:h(?:eures?)?|:)\s*([0-5]\d)?\b"#,
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
