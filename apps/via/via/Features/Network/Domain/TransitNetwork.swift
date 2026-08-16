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
