import CoreLocation
import Foundation

struct GeoCoordinate: Codable, Hashable, Sendable {
    let latitude: Double
    let longitude: Double

    var clCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    func distance(to other: GeoCoordinate) -> CLLocationDistance {
        CLLocation(latitude: latitude, longitude: longitude)
            .distance(from: CLLocation(latitude: other.latitude, longitude: other.longitude))
    }
}

enum TransitMode: String, Codable, Hashable, Sendable {
    case metro
    case rer
    case bus
}

struct RouteBadge: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let shortName: String
    let mode: TransitMode
    let color: String
    let textColor: String
}

struct NetworkSegment: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let coordinates: [GeoCoordinate]
}

struct NetworkRoute: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let shortName: String
    let mode: TransitMode
    let color: String
    let textColor: String
    let segments: [NetworkSegment]
}

struct NetworkStation: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let name: String
    let coordinate: GeoCoordinate
    let routeIds: [String]
}

struct RailMap: Codable, Hashable, Sendable {
    let routes: [NetworkRoute]
    let stations: [NetworkStation]
}

struct TileBounds: Codable, Hashable, Sendable {
    let minLatitude: Double
    let maxLatitude: Double
    let minLongitude: Double
    let maxLongitude: Double
}

struct StationsInArea: Codable, Hashable, Sendable {
    let stations: [NetworkStation]
    let routes: [RouteBadge]
}

struct StationSearchResult: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let name: String
    let coordinate: GeoCoordinate
    let routes: [RouteBadge]
    let distanceMeters: Double?
}

struct AddressSearchResult: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let name: String
    let context: String
    let coordinate: GeoCoordinate
    let distanceMeters: Double?
}

enum SearchResult: Codable, Hashable, Identifiable, Sendable {
    case station(StationSearchResult)
    case address(AddressSearchResult)

    var id: String {
        switch self {
        case .station(let result): result.id
        case .address(let result): result.id
        }
    }

    var name: String {
        switch self {
        case .station(let result): result.name
        case .address(let result): result.name
        }
    }

    var coordinate: GeoCoordinate {
        switch self {
        case .station(let result): result.coordinate
        case .address(let result): result.coordinate
        }
    }

    private enum CodingKeys: String, CodingKey {
        case kind
    }

    private enum Kind: String, Codable {
        case station
        case address
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .kind) {
        case .station:
            self = .station(try StationSearchResult(from: decoder))
        case .address:
            self = .address(try AddressSearchResult(from: decoder))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .station(let result):
            try container.encode(Kind.station, forKey: .kind)
            try result.encode(to: encoder)
        case .address(let result):
            try container.encode(Kind.address, forKey: .kind)
            try result.encode(to: encoder)
        }
    }
}

struct SearchResponse: Codable, Hashable, Sendable {
    let results: [SearchResult]
    let sources: Sources

    struct Sources: Codable, Hashable, Sendable {
        let ban: BANStatus
    }

    enum BANStatus: String, Codable, Hashable, Sendable {
        case ok
        case unavailable
    }
}

struct DepartureGroup: Codable, Hashable, Sendable {
    let route: RouteBadge
    let destination: String
    let departures: [String]
}

struct DeparturesResponse: Codable, Hashable, Sendable {
    let source: Source
    let generatedAt: String
    let groups: [DepartureGroup]

    enum Source: String, Codable, Hashable, Sendable {
        case realtime
        case theoretical
        case unavailable
    }
}

enum LocationAuthorizationState: Equatable, Sendable {
    case notDetermined
    case authorized
    case denied
    case restricted
}

enum LocationUpdate: Sendable {
    case authorizationChanged(LocationAuthorizationState)
    case coordinateUpdated(GeoCoordinate)
}

enum LocationState: Equatable, Sendable {
    case notDetermined
    case loading
    case denied
    case manual
    case ready(GeoCoordinate)

    var canDisplayUserLocation: Bool {
        if case .ready = self { return true }
        return false
    }
}

func makeLocationState(
    for authorization: LocationAuthorizationState,
    coordinate: GeoCoordinate?
) -> LocationState {
    switch authorization {
    case .notDetermined:
        .notDetermined
    case .authorized:
        coordinate.map(LocationState.ready) ?? .loading
    case .denied, .restricted:
        .denied
    }
}

extension String {
    var iso8601Date: Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: self) {
            return date
        }

        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: self)
    }
}

extension Array where Element == NetworkRoute {
    var sortedForDisplay: [NetworkRoute] {
        sorted { left, right in
            let leftNumber = Int(left.shortName.filter(\.isNumber)) ?? Int.max
            let rightNumber = Int(right.shortName.filter(\.isNumber)) ?? Int.max
            if leftNumber != rightNumber { return leftNumber < rightNumber }
            return left.shortName.localizedStandardCompare(right.shortName) == .orderedAscending
        }
    }
}
