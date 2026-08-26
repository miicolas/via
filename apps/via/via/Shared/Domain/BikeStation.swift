import Foundation

struct BikeStationAvailability: Sendable, Hashable, Codable {
    let mechanicalBikes: Int
    let electricBikes: Int
    let docks: Int
    let isInstalled: Bool
    let isRenting: Bool
    let isReturning: Bool
    let lastReportedAt: Date?

    var totalBikes: Int {
        mechanicalBikes + electricBikes
    }

    var isOperational: Bool {
        isInstalled && (isRenting || isReturning)
    }

    /// The spoken inventory, shared by the map annotation and the search row
    /// so VoiceOver never hears two wordings of the same dock.
    var accessibilityDetail: String {
        "\(mechanicalBikes) vélos mécaniques, \(electricBikes) vélos électriques, \(docks) bornettes libres"
    }
}

struct BikeStation: Sendable, Hashable, Identifiable, Codable {
    /// How long a dock count stays believable. One owner for the cached tile's
    /// expiry and for the map's refresh cadence, so they cannot drift apart.
    static let freshness: Duration = .seconds(60)

    let id: String
    let stationCode: String?
    let name: String
    let coordinate: GeoCoordinate
    let capacity: Int
    let availability: BikeStationAvailability?

    var searchResult: SearchResult {
        .bikeStation(BikeStationSearchResult(
            id: id,
            name: name,
            coordinate: coordinate,
            capacity: capacity,
            availability: availability
        ))
    }
}
