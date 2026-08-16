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
}

struct TransitNetwork: Sendable, Hashable {
    let routes: [NetworkRoute]
    let stations: [NetworkStation]
}

struct StationsArea: Sendable, Hashable {
    let stations: [NetworkStation]
    let routes: [RouteBadge]
}

struct ViewportTile: Sendable, Hashable, Identifiable {
    static let sizeInDegrees = 0.025

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
        let latitudeRange = Int(floor(bounds.minLatitude / sizeInDegrees))...Int(floor(bounds.maxLatitude / sizeInDegrees))
        let longitudeRange = Int(floor(bounds.minLongitude / sizeInDegrees))...Int(floor(bounds.maxLongitude / sizeInDegrees))
        return Set(latitudeRange.flatMap { latitude in
            longitudeRange.map { longitude in
                ViewportTile(latitudeIndex: latitude, longitudeIndex: longitude)
            }
        })
    }
}

