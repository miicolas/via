import Foundation

struct StationSearchResult: Sendable, Hashable, Identifiable {
    let id: StationID
    let name: String
    let coordinate: GeoCoordinate
    let routes: [RouteBadge]
    let distanceMeters: Double?
    let accessibility: StationAccessibility?

    init(
        id: StationID,
        name: String,
        coordinate: GeoCoordinate,
        routes: [RouteBadge],
        distanceMeters: Double?,
        accessibility: StationAccessibility? = nil
    ) {
        self.id = id
        self.name = name
        self.coordinate = coordinate
        self.routes = routes
        self.distanceMeters = distanceMeters
        self.accessibility = accessibility
    }
}

struct StationAccessibility: Sendable, Hashable, Codable {
    enum Condition: String, Sendable, Hashable, Codable {
        case reservationRequired
        case staffAssistance
        case autonomous

        var label: String {
            switch self {
            case .reservationRequired: "Sur réservation"
            case .staffAssistance: "Avec un agent"
            case .autonomous: "En autonomie"
            }
        }
    }

    let condition: Condition
    let label: String
    let comment: String?
}

struct AddressSearchResult: Sendable, Hashable, Identifiable {
    let id: String
    let name: String
    let context: String
    let coordinate: GeoCoordinate
    let distanceMeters: Double?
}

/// Single owner of the `"kind:rawID"` composite identifier persisted in
/// recents and used across search, journeys, and the sync wire format.
enum SearchResultID {
    static func encode(kind: RecentSearch.Kind, rawID: String) -> String {
        "\(kind.rawValue):\(rawID)"
    }

    static func decode(_ id: String, kind: RecentSearch.Kind) -> String {
        let prefix = "\(kind.rawValue):"
        guard id.hasPrefix(prefix) else { return id }
        return String(id.dropFirst(prefix.count))
    }
}

enum SearchResult: Sendable, Hashable, Identifiable {
    case station(StationSearchResult)
    case address(AddressSearchResult)

    var id: String {
        switch self {
        case .station(let station):
            SearchResultID.encode(kind: .station, rawID: station.id.rawValue)
        case .address(let address):
            SearchResultID.encode(kind: .address, rawID: address.id)
        }
    }

    var name: String {
        switch self {
        case .station(let station): station.name
        case .address(let address): address.name
        }
    }

    var coordinate: GeoCoordinate {
        switch self {
        case .station(let station): station.coordinate
        case .address(let address): address.coordinate
        }
    }

    var kind: RecentSearch.Kind {
        switch self {
        case .station: .station
        case .address: .address
        }
    }
}

struct SearchResponse: Sendable, Hashable {
    enum AddressSource: String, Sendable, Hashable { case ok, unavailable }

    enum AccessibilitySourceStatus: String, Sendable, Hashable {
        case ok
        case unavailable
    }

    struct AccessibilitySource: Sendable, Hashable {
        let status: AccessibilitySourceStatus
        let sourceUpdatedAt: Date?
        let importedAt: Date?
    }

    let results: [SearchResult]
    let addressSource: AddressSource
    let accessibilitySource: AccessibilitySource

    init(
        results: [SearchResult],
        addressSource: AddressSource,
        accessibilitySource: AccessibilitySource = .init(
            status: .unavailable,
            sourceUpdatedAt: nil,
            importedAt: nil
        )
    ) {
        self.results = results
        self.addressSource = addressSource
        self.accessibilitySource = accessibilitySource
    }
}

struct RecentSearch: Codable, Sendable, Hashable, Identifiable {
    enum Kind: String, Codable, Sendable { case station, address }

    let id: String
    let kind: Kind
    let name: String
    let context: String?
    let coordinate: GeoCoordinate
    let savedAt: Date

    init(
        id: String,
        kind: Kind,
        name: String,
        context: String?,
        coordinate: GeoCoordinate,
        savedAt: Date
    ) {
        self.id = id
        self.kind = kind
        self.name = name
        self.context = context
        self.coordinate = coordinate
        self.savedAt = savedAt
    }

    init(result: SearchResult, savedAt: Date = .now) {
        id = result.id
        name = result.name
        coordinate = result.coordinate
        self.savedAt = savedAt
        switch result {
        case .station:
            kind = .station
            context = nil
        case .address(let address):
            kind = .address
            context = address.context
        }
    }
}

extension RecentSearch {
    /// The raw identifier with the composite `"kind:"` prefix stripped;
    /// tolerates legacy un-prefixed persisted values.
    var resultIdentifier: String {
        SearchResultID.decode(id, kind: kind)
    }

    var searchResult: SearchResult {
        switch kind {
        case .station:
            .station(StationSearchResult(
                id: StationID(rawValue: resultIdentifier),
                name: name,
                coordinate: coordinate,
                routes: [],
                distanceMeters: nil
            ))
        case .address:
            .address(AddressSearchResult(
                id: resultIdentifier,
                name: name,
                context: context ?? "",
                coordinate: coordinate,
                distanceMeters: nil
            ))
        }
    }
}
