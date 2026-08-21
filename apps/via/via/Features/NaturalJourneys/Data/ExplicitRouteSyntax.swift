import Foundation

enum ExplicitRouteSyntax {
    static func originQuery(in phrase: String) -> String? {
        let words = phrase.split(whereSeparator: \.isWhitespace).map(String.init)
        guard let separatorIndex = words.firstIndex(where: {
            $0.compare("vers", options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }),
            separatorIndex > words.startIndex,
            words.index(after: separatorIndex) < words.endIndex
        else {
            return nil
        }

        var originWords = Array(words[..<separatorIndex])
        if let first = originWords.first,
           ["de", "depuis"].contains(first.lowercased())
        {
            originWords.removeFirst()
        }

        let forbiddenWords: Set<String> = [
            "aller", "direction", "j'", "j’", "je", "nous", "on", "rendre", "souhaite",
            "souhaitons", "va", "vais", "veut", "veux", "voudrais",
        ]
        let normalizedOriginWords = originWords.map {
            $0.trimmingCharacters(in: .punctuationCharacters).lowercased()
        }
        guard !originWords.isEmpty,
              forbiddenWords.isDisjoint(with: normalizedOriginWords)
        else {
            return nil
        }

        let origin = originWords
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        return origin.isEmpty ? nil : origin
    }
}
