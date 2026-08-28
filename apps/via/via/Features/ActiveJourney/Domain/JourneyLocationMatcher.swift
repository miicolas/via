import MapKit

/// Matches an actual Core Location fix to the supplied journey geometry.
///
/// This helper never invents a coordinate or advances from the timetable. It
/// only accepts a section when the native location sample is close enough to
/// one of the route polylines.
enum JourneyLocationMatcher {
    static func nearestSectionIndex(
        schedule: [JourneySectionSchedule],
        to coordinate: GeoCoordinate,
        horizontalAccuracy: Double?
    ) -> Int? {
        let tolerance = ActiveJourneyRules.arrivalRadius(horizontalAccuracy: horizontalAccuracy)
        let nearest = schedule.enumerated().compactMap { index, entry in
            Polyline(coordinates: entry.path).nearest(to: coordinate).map { distance in
                (index: index, distance: distance)
            }
        }.min { $0.distance < $1.distance }

        guard let nearest, nearest.distance <= tolerance else { return nil }
        return nearest.index
    }
}

/// Planar helper over a journey segment, in `MKMapPoint` space.
private struct Polyline {
    let points: [MKMapPoint]

    init(coordinates: [GeoCoordinate]) {
        points = coordinates.map { MKMapPoint($0.clLocationCoordinate) }
    }

    func nearest(to coordinate: GeoCoordinate) -> Double? {
        guard points.count >= 2 else { return nil }
        let query = MKMapPoint(coordinate.clLocationCoordinate)
        var nearestDistance: Double?

        for index in points.indices.dropFirst() {
            let projected = Self.nearestPoint(
                to: query,
                from: points[index - 1],
                to: points[index]
            )
            let distance = query.distance(to: projected)
            if nearestDistance == nil || distance < nearestDistance! {
                nearestDistance = distance
            }
        }

        return nearestDistance
    }

    private static func nearestPoint(
        to point: MKMapPoint,
        from start: MKMapPoint,
        to end: MKMapPoint
    ) -> MKMapPoint {
        let deltaX = end.x - start.x
        let deltaY = end.y - start.y
        let lengthSquared = deltaX * deltaX + deltaY * deltaY
        guard lengthSquared > 0 else { return start }

        let projection = ((point.x - start.x) * deltaX + (point.y - start.y) * deltaY)
            / lengthSquared
        let ratio = min(max(0, projection), 1)
        return MKMapPoint(
            x: start.x + deltaX * ratio,
            y: start.y + deltaY * ratio
        )
    }
}
