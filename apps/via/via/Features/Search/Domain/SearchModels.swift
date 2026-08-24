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

struct AddressSearchResult: Sendable, Hashable, Identifiable {
    let id: String
    let name: String
    let context: String
    let coordinate: GeoCoordinate
    let distanceMeters: Double?

    init(
        id: String,
        name: String,
        context: String,
        coordinate: GeoCoordinate,
        distanceMeters: Double?
    ) {
        self.id = id
        self.name = name
        self.context = context
        self.coordinate = coordinate
        self.distanceMeters = distanceMeters
    }

    /// The one line under the name, in the API's own wording when it sent one.
    var subtitle: String {
        context.isEmpty ? "Adresse" : context
    }
}

/// A Vélib' dock as a search result. Its own type, not an address carrying a
/// flag: every `switch` over `SearchResult` is then made to say what a dock
/// looks like instead of silently drawing it as a street.
struct BikeStationSearchResult: Sendable, Hashable, Identifiable {
    let id: String
    let name: String
    let coordinate: GeoCoordinate
    let distanceMeters: Double?
    let capacity: Int
    let availability: BikeStationAvailability?

    init(
        id: String,
        name: String,
        coordinate: GeoCoordinate,
        distanceMeters: Double? = nil,
        capacity: Int = 0,
        availability: BikeStationAvailability? = nil
    ) {
        self.id = id
        self.name = name
        self.coordinate = coordinate
        self.distanceMeters = distanceMeters
        self.capacity = capacity
        self.availability = availability
    }

    /// The wording is the client's now: the dock's kind is on the wire, the
    /// French for it is not.
    static let subtitle = "Station Vélib’"

    /// "4 vélos · 22 bornettes", or the plain label when the feed is silent.
    var inventoryDetail: String {
        guard let availability else { return Self.subtitle }
        let bikes = availability.totalBikes
        return "\(bikes) vélo\(bikes > 1 ? "s" : "") · \(availability.docks) bornette\(availability.docks > 1 ? "s" : "")"
    }
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
    case bikeStation(BikeStationSearchResult)

    var id: String {
        switch self {
        case .station(let station):
            SearchResultID.encode(kind: .station, rawID: station.id.rawValue)
        case .address(let address):
            SearchResultID.encode(kind: .address, rawID: address.id)
        case .bikeStation(let bike):
            SearchResultID.encode(kind: .bikeStation, rawID: bike.id)
        }
    }

    var name: String {
        switch self {
        case .station(let station): station.name
        case .address(let address): address.name
        case .bikeStation(let bike): bike.name
        }
    }

    var coordinate: GeoCoordinate {
        switch self {
        case .station(let station): station.coordinate
        case .address(let address): address.coordinate
        case .bikeStation(let bike): bike.coordinate
        }
    }

    /// The line under the name, wherever a result is listed.
    var subtitle: String {
        switch self {
        case .station(let station):
            let routes = station.routes.prefix(3).map(\.shortName).joined(separator: " · ")
            return routes.isEmpty ? "Station" : routes
        case .address(let address):
            return address.subtitle
        case .bikeStation(let bike):
            return bike.inventoryDetail
        }
    }

    var systemImage: String {
        switch self {
        case .station(let station): station.routes.first?.mode.chipSystemImage ?? "tram.fill"
        case .address: "mappin.and.ellipse"
        case .bikeStation: "bicycle"
        }
    }

    var kind: RecentSearch.Kind {
        switch self {
        case .station: .station
        case .address: .address
        case .bikeStation: .bikeStation
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

    struct ElevatorSource: Sendable, Hashable {
        let status: AccessibilitySourceStatus
        let sourceUpdatedAt: Date?
        let importedAt: Date?
    }

    let results: [SearchResult]
    let addressSource: AddressSource
    let accessibilitySource: AccessibilitySource
    let elevatorSource: ElevatorSource
    let bikeSource: AddressSource

    init(
        results: [SearchResult],
        addressSource: AddressSource,
        accessibilitySource: AccessibilitySource = .init(
            status: .unavailable,
            sourceUpdatedAt: nil,
            importedAt: nil
        ),
        elevatorSource: ElevatorSource = .init(
            status: .unavailable,
            sourceUpdatedAt: nil,
            importedAt: nil
        ),
        bikeSource: AddressSource = .unavailable
    ) {
        self.results = results
        self.addressSource = addressSource
        self.accessibilitySource = accessibilitySource
        self.elevatorSource = elevatorSource
        self.bikeSource = bikeSource
    }
}

struct RecentSearch: Codable, Sendable, Hashable, Identifiable {
    enum Kind: String, Codable, Sendable { case station, address, bikeStation }

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
        case .bikeStation:
            kind = .bikeStation
            context = BikeStationSearchResult.subtitle
        }
    }
}

extension RecentSearch {
    /// Search history is device-local: newest first, one entry per
    /// destination, capped. Every store applies this so an in-memory double
    /// cannot encode a different rule from the persisted one.
    static let historyLimit = 5

    static func normalizedHistory(_ searches: [RecentSearch]) -> [RecentSearch] {
        var newestByID: [String: RecentSearch] = [:]
        for search in searches {
            if search.savedAt >= (newestByID[search.id]?.savedAt ?? .distantPast) {
                newestByID[search.id] = search
            }
        }
        return Array(
            newestByID.values
                .sorted { $0.savedAt > $1.savedAt }
                .prefix(historyLimit)
        )
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
        case .bikeStation:
            // A recent holds a place, not an inventory: the dock's counts are
            // whatever the feed says next time it is opened.
            .bikeStation(BikeStationSearchResult(
                id: resultIdentifier,
                name: name,
                coordinate: coordinate
            ))
        }
    }
}
