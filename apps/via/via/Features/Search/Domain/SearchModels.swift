import Foundation

struct StationSearchResult: Sendable, Hashable, Identifiable {
    let id: StationID
    let name: String
    let coordinate: GeoCoordinate
    let routes: [RouteBadge]
    let distanceMeters: Double?
}

struct AddressSearchResult: Sendable, Hashable, Identifiable {
    let id: String
    let name: String
    let context: String
    let coordinate: GeoCoordinate
    let distanceMeters: Double?
}

enum SearchResult: Sendable, Hashable, Identifiable {
    case station(StationSearchResult)
    case address(AddressSearchResult)

    var id: String {
        switch self {
        case .station(let station): "station:\(station.id.rawValue)"
        case .address(let address): "address:\(address.id)"
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
}

struct SearchResponse: Sendable, Hashable {
    enum AddressSource: String, Sendable, Hashable { case ok, unavailable }

    let results: [SearchResult]
    let addressSource: AddressSource
}

struct RecentSearch: Codable, Sendable, Hashable, Identifiable {
    enum Kind: String, Codable, Sendable { case station, address }

    let id: String
    let kind: Kind
    let name: String
    let context: String?
    let coordinate: GeoCoordinate
    let savedAt: Date

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

