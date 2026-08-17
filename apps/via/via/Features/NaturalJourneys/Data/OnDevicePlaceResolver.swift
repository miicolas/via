import Foundation

enum OnDevicePlaceResolution: Sendable, Hashable {
    case resolved(SearchResult)
    case ambiguous([SearchResult])
    case notFound
    case unavailable

    var candidates: [SearchResult] {
        switch self {
        case .resolved(let result): [result]
        case .ambiguous(let candidates): candidates
        case .notFound, .unavailable: []
        }
    }
}

struct OnDevicePlaceResolver: Sendable {
    private let search: @Sendable (String, GeoCoordinate?) async throws -> SearchResponse

    init(
        search: @escaping @Sendable (String, GeoCoordinate?) async throws -> SearchResponse
    ) {
        self.search = search
    }

    func resolve(
        _ query: String,
        near coordinate: GeoCoordinate?
    ) async throws -> OnDevicePlaceResolution {
        let response = try await search(query, coordinate)
        try Task.checkCancellation()

        let stations = response.results.filter { $0.kind == .station }
        let addresses = response.results.filter { $0.kind == .address }
        let addressQuery = Self.looksLikeAddress(query)
        let relevant = addressQuery ? addresses : stations
        let ranked = relevant.isEmpty ? response.results : relevant
        let normalizedQuery = Self.normalize(query)
        let exact = ranked.filter { Self.normalize($0.name) == normalizedQuery }

        if exact.count == 1, let result = exact.first {
            return .resolved(result)
        }
        if ranked.count == 1, let result = ranked.first {
            return .resolved(result)
        }
        if !ranked.isEmpty {
            return .ambiguous(Array(ranked.prefix(5)))
        }
        return response.addressSource == .unavailable ? .unavailable : .notFound
    }

    static func normalize(_ value: String) -> String {
        let decomposed = value.decomposedStringWithCanonicalMapping
        let scalars = decomposed.unicodeScalars.filter {
            CharacterSet.nonBaseCharacters.contains($0) == false
        }
        return String(String.UnicodeScalarView(scalars))
            .replacingOccurrences(
                of: "[-‐‑‒–—]",
                with: " ",
                options: .regularExpression
            )
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased(with: Locale(identifier: "fr_FR"))
    }

    private static func looksLikeAddress(_ query: String) -> Bool {
        query.trimmingCharacters(in: .whitespacesAndNewlines).range(
            of: "(?:^|\\s)(?:\\d{1,4}|rue|route|avenue|av|boulevard|bd|allée|allee|chemin|impasse|quai|passage|place|square|cours|voie|sentier|résidence|residence)(?:\\s|$)",
            options: [.regularExpression, .caseInsensitive]
        ) != nil
    }
}
