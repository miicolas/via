import Foundation

struct ViewportRegion: Hashable, Sendable {
    let latitude: Double
    let longitude: Double
    let latitudeDelta: Double
    let longitudeDelta: Double
}

enum ViewportTiles {
    static let tileSizeDegrees = 0.02

    static func keys(for region: ViewportRegion) -> [String] {
        let south = region.latitude - region.latitudeDelta / 2
        let north = region.latitude + region.latitudeDelta / 2
        let west = region.longitude - region.longitudeDelta / 2
        let east = region.longitude + region.longitudeDelta / 2

        let firstRow = Int(floor(south / tileSizeDegrees))
        let lastRow = Int(floor(north / tileSizeDegrees))
        let firstColumn = Int(floor(west / tileSizeDegrees))
        let lastColumn = Int(floor(east / tileSizeDegrees))

        return (firstRow...lastRow).flatMap { row in
            (firstColumn...lastColumn).map { column in
                "\(row):\(column)"
            }
        }
    }

    static func bounds(for key: String) -> TileBounds? {
        let parts = key.split(separator: ":")
        guard parts.count == 2, let row = Int(parts[0]), let column = Int(parts[1]) else {
            return nil
        }

        return TileBounds(
            minLatitude: Double(row) * tileSizeDegrees,
            maxLatitude: Double(row + 1) * tileSizeDegrees,
            minLongitude: Double(column) * tileSizeDegrees,
            maxLongitude: Double(column + 1) * tileSizeDegrees
        )
    }
}
