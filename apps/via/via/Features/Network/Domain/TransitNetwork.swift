import Foundation

struct NetworkSegment: Sendable, Hashable, Identifiable {
    let id: String
    let coordinates: [GeoCoordinate]
}

struct NetworkRoute: Sendable, Hashable, Identifiable {
    let badge: RouteBadge
    let segments: [NetworkSegment]

    var id: RouteID { badge.id }
}

struct NetworkStation: Sendable, Hashable, Identifiable {
    let id: StationID
    let name: String
    let coordinate: GeoCoordinate
    let routeIDs: [RouteID]
    let accessibility: StationAccessibility?
    let hasElevators: Bool
    let toilets: StationToilets?
    let fountains: StationFountains?

    init(
        id: StationID,
        name: String,
        coordinate: GeoCoordinate,
        routeIDs: [RouteID],
        accessibility: StationAccessibility? = nil,
        hasElevators: Bool = false,
        toilets: StationToilets? = nil,
        fountains: StationFountains? = nil
    ) {
        self.id = id
        self.name = name
        self.coordinate = coordinate
        self.routeIDs = routeIDs
        self.accessibility = accessibility
        self.hasElevators = hasElevators
        self.toilets = toilets
        self.fountains = fountains
    }
}

struct StationToilets: Sendable, Hashable, Codable {
    let label: String
    let detail: String?
}

struct StationFountains: Sendable, Hashable, Codable {
    enum Status: String, Sendable, Hashable, Codable {
        case available
        case unavailable
    }

    let status: Status
    let label: String
    let detail: String?
}

struct TransitNetwork: Sendable, Hashable {
    let routes: [NetworkRoute]
    let stations: [NetworkStation]
}

struct StationsArea: Sendable, Hashable {
    let stations: [NetworkStation]
    let routes: [RouteBadge]

    init(stations: [NetworkStation], routes: [RouteBadge]) {
        self.stations = stations
        self.routes = routes
    }
}

/// The Vélib' docks of the same viewport. A separate payload because it ages
/// in a minute while `StationsArea` stands until the next reference import —
/// one tile carrying both dragged the stations down to the docks' cadence.
struct BikeStationsArea: Sendable, Hashable {
    let stations: [BikeStation]
    let sourceAvailable: Bool

    init(stations: [BikeStation] = [], sourceAvailable: Bool = true) {
        self.stations = stations
        self.sourceAvailable = sourceAvailable
    }
}

struct ViewportTile: Sendable, Hashable, Identifiable {
    static let sizeInDegrees = 0.025
    static let maximumVisibleTileCount = 64

    let latitudeIndex: Int
    let longitudeIndex: Int

    var id: String { "\(latitudeIndex):\(longitudeIndex)" }

    var bounds: GeoBounds {
        let size = Self.sizeInDegrees
        let minLatitude = Double(latitudeIndex) * size
        let minLongitude = Double(longitudeIndex) * size
        return GeoBounds(
            minLatitude: minLatitude,
            maxLatitude: minLatitude + size,
            minLongitude: minLongitude,
            maxLongitude: minLongitude + size
        )
    }

    static func covering(_ bounds: GeoBounds) -> Set<ViewportTile> {
        guard bounds.isValid else { return [] }
        let minimumLatitudeIndex = Int(floor(bounds.minLatitude / sizeInDegrees))
        let maximumLatitudeIndex = Int(floor(bounds.maxLatitude / sizeInDegrees))
        let minimumLongitudeIndex = Int(floor(bounds.minLongitude / sizeInDegrees))
        let maximumLongitudeIndex = Int(floor(bounds.maxLongitude / sizeInDegrees))
        let latitudeCount = maximumLatitudeIndex - minimumLatitudeIndex + 1
        let longitudeCount = maximumLongitudeIndex - minimumLongitudeIndex + 1

        guard
            latitudeCount > 0,
            longitudeCount > 0,
            latitudeCount <= maximumVisibleTileCount,
            longitudeCount <= maximumVisibleTileCount / latitudeCount
        else { return [] }

        let latitudeRange = minimumLatitudeIndex...maximumLatitudeIndex
        let longitudeRange = minimumLongitudeIndex...maximumLongitudeIndex
        return Set(latitudeRange.flatMap { latitude in
            longitudeRange.map { longitude in
                ViewportTile(latitudeIndex: latitude, longitudeIndex: longitude)
            }
        })
    }
}
