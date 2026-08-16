import Foundation

struct CoordinateDTO: Codable {
    let latitude: Double
    let longitude: Double

    init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    init(_ value: GeoCoordinate) {
        self.init(latitude: value.latitude, longitude: value.longitude)
    }

    var domain: GeoCoordinate {
        GeoCoordinate(latitude: latitude, longitude: longitude)
    }
}

struct RouteBadgeDTO: Codable {
    let id: String
    let shortName: String
    let mode: String
    let color: String
    let textColor: String

    init(id: String, shortName: String, mode: String, color: String, textColor: String) {
        self.id = id
        self.shortName = shortName
        self.mode = mode
        self.color = color
        self.textColor = textColor
    }

    init(_ value: RouteBadge) {
        self.init(
            id: value.id.rawValue,
            shortName: value.shortName,
            mode: value.mode.rawValue,
            color: value.colorHex,
            textColor: value.textColorHex
        )
    }

    func domain() throws -> RouteBadge {
        guard let mode = TransitMode(rawValue: mode) else { throw ViaError.decoding }
        return RouteBadge(
            id: RouteID(rawValue: id),
            shortName: shortName,
            mode: mode,
            colorHex: color,
            textColorHex: textColor
        )
    }
}
