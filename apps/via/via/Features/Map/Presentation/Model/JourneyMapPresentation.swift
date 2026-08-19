import MapKit

struct JourneyMapSegment: Identifiable, Sendable, Hashable {
    let id: String
    let coordinates: [GeoCoordinate]
    let colorHex: String?
    let isPedestrian: Bool
    let isStationary: Bool
}

/// Map-ready projection of a selected journey. The map never needs to learn
/// how journey sections, fallback geometry, or route colors are encoded.
struct JourneyMapPresentation: Identifiable, Sendable, Hashable {
    let id: JourneyID
    let segments: [JourneyMapSegment]

    init(journey: Journey) {
        id = journey.id
        segments = journey.sections.map { section in
            JourneyMapSegment(
                id: section.id,
                coordinates: section.geometry.isEmpty
                    ? [section.from.coordinate, section.to.coordinate]
                    : section.geometry,
                colorHex: section.route?.colorHex,
                isPedestrian: section.kind == .walk || section.kind == .transfer,
                isStationary: section.kind == .wait
            )
        }
    }

    var mapRect: MKMapRect? {
        mapRect(for: segments.flatMap(\.coordinates))
    }

    func mapRect(for segmentID: String?) -> MKMapRect? {
        guard let segmentID,
              let segment = segments.first(where: { $0.id == segmentID }) else {
            return mapRect
        }
        return mapRect(for: segment.coordinates)
    }

    private func mapRect(for coordinates: [GeoCoordinate]) -> MKMapRect? {
        let points = coordinates.map { MKMapPoint($0.clLocationCoordinate) }
        guard let first = points.first else { return nil }

        let rect = points.dropFirst().reduce(
            MKMapRect(x: first.x, y: first.y, width: 0, height: 0)
        ) { rect, point in
            rect.union(MKMapRect(x: point.x, y: point.y, width: 0, height: 0))
        }
        let minimumSize = 1_500.0
        let horizontalPadding = max(rect.size.width * 0.18, minimumSize)
        let verticalPadding = max(rect.size.height * 0.18, minimumSize)
        return rect.insetBy(dx: -horizontalPadding, dy: -verticalPadding)
    }
}
