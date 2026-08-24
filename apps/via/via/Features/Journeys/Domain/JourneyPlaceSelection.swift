import Foundation

enum JourneyPlaceSelection: Sendable, Hashable, Identifiable {
    case currentLocation(GeoCoordinate)
    case station(
        id: StationID,
        name: String,
        coordinate: GeoCoordinate,
        routes: [RouteBadge]
    )
    case address(
        id: String,
        name: String,
        context: String?,
        coordinate: GeoCoordinate
    )

    /// Stands in for the device position in the wire contract's address slot;
    /// see `journeyDestination`.
    static let currentLocationID = "current-location"

    var id: String {
        switch self {
        case .currentLocation:
            Self.currentLocationID
        case .station(let id, _, _, _):
            SearchResultID.encode(kind: .station, rawID: id.rawValue)
        case .address(let id, _, _, _):
            SearchResultID.encode(kind: .address, rawID: id)
        }
    }

    var isCurrentLocation: Bool {
        if case .currentLocation = self { return true }
        return false
    }

    var name: String {
        switch self {
        case .currentLocation:
            "Ma position"
        case .station(_, let name, _, _), .address(_, let name, _, _):
            name
        }
    }

    var context: String? {
        guard case .address(_, _, let context, _) = self else { return nil }
        return context
    }

    var coordinate: GeoCoordinate {
        switch self {
        case .currentLocation(let coordinate),
             .station(_, _, let coordinate, _),
             .address(_, _, _, let coordinate):
            coordinate
        }
    }

    var routes: [RouteBadge] {
        guard case .station(_, _, _, let routes) = self else { return [] }
        return routes
    }

    var journeyDestination: JourneyDestination {
        switch self {
        case .currentLocation(let coordinate):
            // The wire contract plans by coordinate and currently models every
            // destination as a station or address. This local sentinel keeps
            // swapping with "Ma position" wire-compatible.
            .address(
                id: Self.currentLocationID,
                name: "Ma position",
                context: nil,
                coordinate: coordinate
            )
        case .station(let id, let name, let coordinate, _):
            .station(id: id, name: name, coordinate: coordinate)
        case .address(let id, let name, let context, let coordinate):
            .address(id: id, name: name, context: context, coordinate: coordinate)
        }
    }

    init(_ result: SearchResult) {
        switch result {
        case .station(let station):
            self = .station(
                id: station.id,
                name: station.name,
                coordinate: station.coordinate,
                routes: station.routes
            )
        case .address(let address):
            self = .address(
                id: address.id,
                name: address.name,
                context: address.context,
                coordinate: address.coordinate
            )
        case .bikeStation(let bike):
            // A dock is somewhere you walk to: it plans as an address, its own
            // result kind being about how it is drawn, not how it is routed.
            self = .address(
                id: bike.id,
                name: bike.name,
                context: BikeStationSearchResult.subtitle,
                coordinate: bike.coordinate
            )
        }
    }

    init(_ recent: RecentSearch) {
        self.init(recent.searchResult)
    }
}
