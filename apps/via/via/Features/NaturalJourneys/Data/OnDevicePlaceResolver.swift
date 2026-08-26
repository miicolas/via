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

/// A semantic preference extracted from the person's own words. It narrows
/// catalog ranking but never lets the model choose a concrete result.
enum NaturalPlaceKindHint: Sendable, Hashable {
    case automatic
    case transit
    case address
    case locality

    static func inferred(from evidence: String?) -> Self {
        guard let evidence else { return .automatic }
        let normalized = OnDevicePlaceResolver.normalize(evidence)
        if normalized.range(
            of: #"(?:^|[\s'’])(?:station|metro|gare|rer|tram|arret|bus|train|transilien)(?:\s|$)"#,
            options: .regularExpression,
        ) != nil {
            return .transit
        }
        if normalized.range(
            of: #"(?:^|[\s'’])(?:centre ville|centre|ville|commune)(?:\s|$)"#,
            options: .regularExpression,
        ) != nil {
            return .locality
        }
        if normalized.range(
            of: #"(?:^|[\s'’])(?:adresse|address)(?:\s|$)"#,
            options: .regularExpression,
        ) != nil {
            return .address
        }
        return .automatic
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
        hint: NaturalPlaceKindHint = .automatic,
        near coordinate: GeoCoordinate?
    ) async throws -> OnDevicePlaceResolution {
        let intent = Self.queryIntent(for: query, fallbackPreference: hint)
        let primaryResolution = try await searchAndRank(intent, near: coordinate)

        guard let fallbackSearchText = intent.fallbackSearchText,
              Self.normalize(fallbackSearchText) != Self.normalize(intent.searchText)
        else {
            return primaryResolution
        }

        let shouldTryFallback = switch primaryResolution {
        case .resolved(let result):
            !Self.isStrongMatch(result, for: intent.searchText)
        case .ambiguous, .notFound:
            true
        case .unavailable:
            false
        }
        guard shouldTryFallback else { return primaryResolution }

        let fallbackIntent = QueryIntent(
            searchText: fallbackSearchText,
            fallbackSearchText: nil,
            preference: intent.preference,
            hasStreetNumber: intent.hasStreetNumber,
        )
        let fallbackResolution = try await searchAndRank(
            fallbackIntent,
            near: coordinate
        )

        if case .notFound = primaryResolution {
            return fallbackResolution
        }
        if case .resolved(let result) = fallbackResolution,
           Self.isStrongMatch(result, for: fallbackSearchText)
        {
            return fallbackResolution
        }
        return primaryResolution
    }

    private func searchAndRank(
        _ intent: QueryIntent,
        near coordinate: GeoCoordinate?
    ) async throws -> OnDevicePlaceResolution {
        let response = try await search(intent.searchText, coordinate)
        try Task.checkCancellation()

        let stations = response.results.filter { $0.kind == .station }
        let addresses = response.results.filter { $0.kind == .address }
        let normalizedQuery = Self.normalize(intent.searchText)
        let exactStations = stations.filter { Self.normalize($0.name) == normalizedQuery }
        let exactAddresses = addresses.filter { Self.normalize($0.name) == normalizedQuery }

        switch intent.preference {
        case .transit:
            if exactStations.count == 1, let result = exactStations.first {
                return .resolved(result)
            }
        case .address, .locality:
            if exactAddresses.count == 1, let result = exactAddresses.first {
                return .resolved(result)
            }
        case .automatic:
            if intent.hasStreetNumber,
               exactAddresses.count == 1,
               let result = exactAddresses.first
            {
                return .resolved(result)
            }
            // In a transit app, a canonical station name such as
            // « Place d’Italie » remains a station even though its wording also
            // resembles a postal address.
            if exactStations.count == 1, let result = exactStations.first {
                return .resolved(result)
            }
        }

        let addressQuery = switch intent.preference {
        case .address, .locality: true
        case .transit: false
        case .automatic: intent.hasStreetNumber || Self.looksLikeAddress(intent.searchText)
        }
        let relevant = addressQuery ? addresses : stations
        let ranked = switch intent.preference {
        case .transit, .address, .locality:
            // An explicit type is a closed catalog constraint. Crossing that
            // boundary silently changes what the person asked for.
            relevant
        case .automatic:
            relevant.isEmpty ? response.results : relevant
        }
        let exact = ranked.filter { Self.normalize($0.name) == normalizedQuery }

        if exact.count == 1, let result = exact.first {
            return .resolved(result)
        }
        if let result = Self.uniqueCloseMatch(for: normalizedQuery, in: ranked) {
            return .resolved(result)
        }
        if !addressQuery,
           let result = Self.uniquePrimaryTransitMatch(
               for: normalizedQuery,
               in: ranked
           )
        {
            return .resolved(result)
        }
        if ranked.count == 1, let result = ranked.first {
            return .resolved(result)
        }
        if !ranked.isEmpty {
            return .ambiguous(Array(ranked.prefix(5)))
        }
        return switch intent.preference {
        case .transit:
            .notFound
        case .address, .locality, .automatic:
            response.addressSource == .unavailable ? .unavailable : .notFound
        }
    }

    /// A bare commune can match one rail station and several incidental bus
    /// stops (for example Chatou). When exactly one rapid-transit station starts
    /// with the requested name, that station is the useful default. Anything
    /// less selective remains a clarification.
    private static func uniquePrimaryTransitMatch(
        for normalizedQuery: String,
        in results: [SearchResult],
    ) -> SearchResult? {
        let rapidModes: Set<TransitMode> = [.metro, .rer, .transilien, .tram]
        let matches = results.filter { result in
            guard case .station(let station) = result,
                  station.routes.contains(where: { rapidModes.contains($0.mode) })
            else { return false }

            let name = normalize(station.name)
            return name.hasPrefix("\(normalizedQuery) ")
                || normalizedQuery.hasPrefix("\(name) ")
        }
        return matches.count == 1 ? matches[0] : nil
    }

    /// Used by catalog-grounded shorthand parsing. A lone weak search result
    /// must not be enough to split arbitrary prose into an origin/destination
    /// pair; the candidate has to match the supplied mention itself.
    static func isStrongMatch(_ result: SearchResult, for query: String) -> Bool {
        let intent = queryIntent(for: query, fallbackPreference: .automatic)
        let normalizedQuery = normalize(intent.searchText)
        let normalizedName = normalize(result.name)
        if normalizedName == normalizedQuery { return true }

        let allowedDistance = switch normalizedQuery.count {
        case 12...: 2
        case 6...: 1
        default: 0
        }
        if allowedDistance > 0,
           editDistance(normalizedQuery, normalizedName) <= allowedDistance
        {
            return true
        }

        guard case .station(let station) = result else { return false }
        let rapidModes: Set<TransitMode> = [.metro, .rer, .transilien, .tram]
        guard station.routes.contains(where: { rapidModes.contains($0.mode) }) else {
            return false
        }
        return normalizedName.hasPrefix("\(normalizedQuery) ")
            || normalizedQuery.hasPrefix("\(normalizedName) ")
    }

    /// Accepts a small typo only when exactly one result is close enough. The
    /// uniqueness requirement keeps short or genuinely ambiguous place names
    /// on the clarification path.
    private static func uniqueCloseMatch(
        for normalizedQuery: String,
        in results: [SearchResult],
    ) -> SearchResult? {
        let allowedDistance = switch normalizedQuery.count {
        case 12...: 2
        case 6...: 1
        default: 0
        }
        guard allowedDistance > 0 else { return nil }

        let close = results.filter {
            editDistance(normalizedQuery, normalize($0.name)) <= allowedDistance
        }
        return close.count == 1 ? close[0] : nil
    }

    private static func editDistance(_ lhs: String, _ rhs: String) -> Int {
        let left = Array(lhs)
        let right = Array(rhs)
        var previous = Array(0 ... right.count)

        for (leftIndex, leftCharacter) in left.enumerated() {
            var current = [leftIndex + 1]
            current.reserveCapacity(right.count + 1)

            for (rightIndex, rightCharacter) in right.enumerated() {
                current.append(min(
                    current[rightIndex] + 1,
                    previous[rightIndex + 1] + 1,
                    previous[rightIndex] + (leftCharacter == rightCharacter ? 0 : 1),
                ))
            }
            previous = current
        }

        return previous[right.count]
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

    private struct QueryIntent {
        let searchText: String
        let fallbackSearchText: String?
        let preference: NaturalPlaceKindHint
        let hasStreetNumber: Bool
    }

    /// Separate a composable semantic qualifier from the catalog query. A
    /// canonical railway name is searched intact first; only a failed or weak
    /// result tries the qualifier-free form (for example « gare de Chatou » →
    /// « Chatou »). Other transport wrappers can stack (« station RER »,
    /// « station de tram », « arrêt de bus ») without knowing any place name.
    private static func queryIntent(
        for rawQuery: String,
        fallbackPreference: NaturalPlaceKindHint,
    ) -> QueryIntent {
        let normalized = normalize(rawQuery)
        let preference: NaturalPlaceKindHint
        let searchText: String
        let fallbackSearchText: String?

        if hasPrefix(
            #"^\s*(?:(?:à|a)\s+)?(?:l['’]\s*)?(?:adresse|address)(?:\s|[:,-]|$)"#,
            in: rawQuery
        ) {
            preference = .address
            searchText = strippingSemanticPrefix(
                #"^\s*(?:(?:à|a)\s+)?(?:l['’]\s*)?(?:adresse|address)(?:\s*[:,-]\s*|\s+)(?:(?:de|du|des)\s+|d['’]\s*)?"#,
                from: rawQuery
            ) ?? cleaned(rawQuery)
            fallbackSearchText = nil
        } else if hasPrefix(
            #"^\s*(?:le\s+|la\s+|l['’]\s*)?(?:centre(?:-|\s+)?ville|centre|ville|commune)(?:\s|[:,-]|$)"#,
            in: rawQuery
        ) {
            preference = .locality
            searchText = strippingSemanticPrefix(
                #"^\s*(?:le\s+|la\s+|l['’]\s*)?(?:centre(?:-|\s+)?ville|centre|ville|commune)(?:\s*[:,-]\s*|\s+)(?:(?:de|du|des)\s+|d['’]\s*)?"#,
                from: rawQuery
            ) ?? cleaned(rawQuery)
            fallbackSearchText = nil
        } else if hasPrefix(
            #"^\s*(?:le\s+|la\s+|l['’]\s*)?(?:station|m[eé]tro|gare|rer|tram(?:way)?|arr[eê]t|bus|train|transilien)(?:\s|[:,-]|$)"#,
            in: rawQuery
        ) {
            preference = .transit
            if hasPrefix(
                #"^\s*(?:le\s+|la\s+)?gare(?:\s|[:,-]|$)"#,
                in: rawQuery
            ) {
                let canonical = rawQuery.replacingOccurrences(
                    of: #"^\s*(?:le\s+|la\s+)(?=gare(?:\s|[:,-]|$))"#,
                    with: "",
                    options: [.regularExpression, .caseInsensitive]
                )
                searchText = cleaned(canonical)
                fallbackSearchText = strippingSemanticPrefix(
                    #"^\s*gare(?:\s*[:,-]\s*|\s+)(?:(?:(?:de|du|des)\s+|d['’]\s*)?(?:rer|sncf|transilien|train|ferroviaire|routi[eè]re)(?:\s*[:,-]\s*|\s+))?(?:(?:de|du|des)\s+|d['’]\s*)?"#,
                    from: canonical
                )
            } else if hasPrefix(
                #"^\s*(?:le\s+|la\s+)?station(?:\s|[:,-]|$)"#,
                in: rawQuery
            ) {
                searchText = strippingSemanticPrefix(
                    #"^\s*(?:le\s+|la\s+)?station(?:\s*[:,-]\s*|\s+)(?:(?:(?:de|du|des)\s+|d['’]\s*)?(?:m[eé]tro|rer|tram(?:way)?|bus|train|transilien|sncf|ferroviaire)(?:\s*[:,-]\s*|\s+))?(?:(?:de|du|des)\s+|d['’]\s*)?"#,
                    from: rawQuery
                ) ?? cleaned(rawQuery)
                fallbackSearchText = nil
            } else if hasPrefix(
                #"^\s*(?:l['’]\s*)?arr[eê]t(?:\s|[:,-]|$)"#,
                in: rawQuery
            ) {
                searchText = strippingSemanticPrefix(
                    #"^\s*(?:l['’]\s*)?arr[eê]t(?:\s*[:,-]\s*|\s+)(?:(?:(?:de|du|des)\s+|d['’]\s*)?bus(?:\s*[:,-]\s*|\s+))?(?:(?:de|du|des)\s+|d['’]\s*)?"#,
                    from: rawQuery
                ) ?? cleaned(rawQuery)
                fallbackSearchText = nil
            } else {
                searchText = strippingSemanticPrefix(
                    #"^\s*(?:le\s+|la\s+)?(?:m[eé]tro|rer|tram(?:way)?|bus|train|transilien)(?:\s*[:,-]\s*|\s+)(?:(?:de|du|des)\s+|d['’]\s*)?"#,
                    from: rawQuery
                ) ?? cleaned(rawQuery)
                fallbackSearchText = nil
            }
        } else {
            preference = fallbackPreference
            searchText = cleaned(rawQuery)
            fallbackSearchText = nil
        }

        let hasStreetNumber = normalized.range(
            of: #"(?:^|\s)\d{1,4}(?:\s|$)"#,
            options: .regularExpression
        ) != nil
        return QueryIntent(
            searchText: searchText.isEmpty ? rawQuery : searchText,
            fallbackSearchText: fallbackSearchText,
            preference: preference,
            hasStreetNumber: hasStreetNumber,
        )
    }

    private static func hasPrefix(_ pattern: String, in value: String) -> Bool {
        value.range(
            of: pattern,
            options: [.regularExpression, .caseInsensitive]
        ) != nil
    }

    private static func strippingSemanticPrefix(
        _ pattern: String,
        from value: String
    ) -> String? {
        let stripped = value.replacingOccurrences(
            of: pattern,
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )
        let result = cleaned(stripped)
        return result.isEmpty || result == cleaned(value) ? nil : result
    }

    private static func cleaned(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: .punctuationCharacters)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func looksLikeAddress(_ query: String) -> Bool {
        query.trimmingCharacters(in: .whitespacesAndNewlines).range(
            of: "(?:^|\\s)(?:\\d{1,4}|rue|route|avenue|av|boulevard|bd|allée|allee|chemin|impasse|quai|passage|place|square|cours|voie|sentier|résidence|residence)(?:\\s|$)",
            options: [.regularExpression, .caseInsensitive]
        ) != nil
    }
}
