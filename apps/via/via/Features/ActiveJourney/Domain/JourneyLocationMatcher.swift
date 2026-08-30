import MapKit

/// The station marker a fresh Core Location fix puts on the live journey rail.
/// A fix inside a station's radius marks that station as current; between two
/// stations the marker moves ahead to the next call, like an onboard RER map.
struct JourneyStopProgress: Sendable, Hashable {
    enum Status: Sendable, Hashable {
        case current
        case next
    }

    let sectionID: String
    let stopID: String
    let status: Status
    let stopIndex: Int
    let stopCount: Int
    let stopName: String
    let alightingStopName: String
    let alightingCoordinate: GeoCoordinate

    /// Calls still to make after the current station, or including the next
    /// station while the train is between calls. Both states therefore show
    /// the same stable count as the diode leaves one station for the next.
    var remainingStopCount: Int {
        max(0, stopCount - stopIndex - (status == .current ? 1 : 0))
    }
}

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

    /// Resolves the one stop whose white rail hole becomes the live amber
    /// diode. Timetable times never participate: without a fix close to the
    /// section geometry, no station is highlighted.
    static func stopProgress(
        sectionID: String,
        stops: [JourneyStop],
        path: [GeoCoordinate],
        to coordinate: GeoCoordinate,
        horizontalAccuracy: Double?
    ) -> JourneyStopProgress? {
        guard !stops.isEmpty else { return nil }

        let tolerance = ActiveJourneyRules.arrivalRadius(
            horizontalAccuracy: horizontalAccuracy
        )
        let nearestStop = stops.enumerated().min {
            ActiveJourneyRules.distance(from: coordinate, to: $0.element.coordinate)
                < ActiveJourneyRules.distance(from: coordinate, to: $1.element.coordinate)
        }

        if let nearestStop,
           ActiveJourneyRules.distance(from: coordinate, to: nearestStop.element.coordinate)
            <= tolerance {
            return progress(
                sectionID: sectionID,
                stops: stops,
                stopIndex: nearestStop.offset,
                status: .current
            )
        }

        let polyline = Polyline(coordinates: path)
        guard let locationProjection = polyline.projection(to: coordinate),
              locationProjection.distance <= tolerance else {
            return nil
        }

        let projectedStops = stops.enumerated().compactMap { index, stop in
            polyline.projection(to: stop.coordinate).map { projection in
                (index: index, stop: stop, distanceFromStart: projection.distanceFromStart)
            }
        }
        guard !projectedStops.isEmpty else { return nil }

        // A few metres of slack prevents GPS jitter at the station centre from
        // bouncing the diode backwards to the stop the train just left.
        let progressSlack = max(8, min(30, (horizontalAccuracy ?? 10) * 0.5))
        let next = projectedStops
            .filter {
                $0.distanceFromStart
                    > locationProjection.distanceFromStart + progressSlack
            }
            .min { $0.distanceFromStart < $1.distanceFromStart }
            ?? projectedStops.max { $0.distanceFromStart < $1.distanceFromStart }

        guard let next else { return nil }
        return progress(
            sectionID: sectionID,
            stops: stops,
            stopIndex: next.index,
            status: .next
        )
    }

    /// A multi-stop service warns at (or just after) the penultimate call. A
    /// direct service has no previous call, so it waits until the train is
    /// physically close enough to make the warning timely instead of sounding
    /// as soon as it leaves its origin.
    static func shouldAlertForAlighting(
        progress: JourneyStopProgress,
        coordinate: GeoCoordinate
    ) -> Bool {
        guard progress.remainingStopCount <= 1 else { return false }
        if progress.remainingStopCount == 0 { return true }
        if progress.stopCount > 2 { return true }
        return ActiveJourneyRules.distance(
            from: coordinate,
            to: progress.alightingCoordinate
        ) <= 900
    }

    private static func progress(
        sectionID: String,
        stops: [JourneyStop],
        stopIndex: Int,
        status: JourneyStopProgress.Status
    ) -> JourneyStopProgress? {
        guard stops.indices.contains(stopIndex), let alighting = stops.last else { return nil }
        let stop = stops[stopIndex]
        return JourneyStopProgress(
            sectionID: sectionID,
            stopID: stop.id,
            status: status,
            stopIndex: stopIndex,
            stopCount: stops.count,
            stopName: stop.name,
            alightingStopName: alighting.name,
            alightingCoordinate: alighting.coordinate
        )
    }
}

/// Planar helper over a journey segment, in `MKMapPoint` space.
private struct Polyline {
    struct Projection {
        let distance: Double
        let distanceFromStart: Double
    }

    let points: [MKMapPoint]

    init(coordinates: [GeoCoordinate]) {
        points = coordinates.map { MKMapPoint($0.clLocationCoordinate) }
    }

    func nearest(to coordinate: GeoCoordinate) -> Double? {
        projection(to: coordinate)?.distance
    }

    func projection(to coordinate: GeoCoordinate) -> Projection? {
        guard points.count >= 2 else { return nil }
        let query = MKMapPoint(coordinate.clLocationCoordinate)
        var nearest: Projection?
        var traversedDistance = 0.0

        for index in points.indices.dropFirst() {
            let start = points[index - 1]
            let end = points[index]
            let projected = Self.nearestPoint(
                to: query,
                from: start,
                to: end
            )
            let distance = query.distance(to: projected)
            let candidate = Projection(
                distance: distance,
                distanceFromStart: traversedDistance + start.distance(to: projected)
            )
            if nearest == nil || distance < nearest!.distance {
                nearest = candidate
            }
            traversedDistance += start.distance(to: end)
        }

        return nearest
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
