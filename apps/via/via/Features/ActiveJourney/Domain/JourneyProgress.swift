import Foundation
import MapKit

/// Where the traveller is inside the journey, as a continuous value.
///
/// The session only stores a discrete `currentSectionIndex`. That is enough to
/// pick an instruction, but not to move a cursor down the timeline rail or to
/// split the drawn route into "already travelled" and "still to come".
struct JourneyProgress: Sendable, Hashable {
    let sectionIndex: Int
    /// 0…1 inside the current section.
    let fractionInSection: Double
    /// 0…1 across the whole journey, weighted by section durations.
    let overallFraction: Double
    /// Stops already called at on the current transit section, boarding excluded.
    let passedStopCount: Int
    /// `nil` outside a transit section, or when the planner gave no stop list.
    let stopsUntilAlighting: Int?
    /// Point on the route matching `fractionInSection`, when geometry allows it.
    let projectedCoordinate: GeoCoordinate?
    /// `false` when the value comes from schedule interpolation alone.
    let isLocationDerived: Bool

    var isEstimated: Bool { !isLocationDerived }

    static let start = JourneyProgress(
        sectionIndex: 0,
        fractionInSection: 0,
        overallFraction: 0,
        passedStopCount: 0,
        stopsUntilAlighting: nil,
        projectedCoordinate: nil,
        isLocationDerived: false
    )
}

enum JourneyProgressProjector {
    /// Projects a location fix — when there is one — onto the current section,
    /// falling back to schedule interpolation so the cursor keeps moving
    /// underground, on a restored session, or before the first fix arrives.
    static func progress(
        schedule: [JourneySectionSchedule],
        sectionIndex: Int,
        at date: Date,
        coordinate: GeoCoordinate?,
        horizontalAccuracy: Double?
    ) -> JourneyProgress {
        guard !schedule.isEmpty else { return .start }

        let index = min(max(0, sectionIndex), schedule.count - 1)
        let entry = schedule[index]
        let timeFraction = fraction(of: date, between: entry.startsAt, and: entry.endsAt)

        let route = Polyline(coordinates: entry.path)
        let match = coordinate.flatMap { coordinate in
            project(
                coordinate: coordinate,
                onto: route,
                tolerance: ActiveJourneyRules.arrivalRadius(horizontalAccuracy: horizontalAccuracy)
            )
        }

        let isLocationDerived = match != nil
        let fractionInSection = match?.fraction ?? timeFraction
        let passed = passedStopCount(
            section: entry.section,
            route: route,
            fractionInSection: fractionInSection,
            isLocationDerived: isLocationDerived,
            at: date
        )

        return JourneyProgress(
            sectionIndex: index,
            fractionInSection: fractionInSection,
            overallFraction: overallFraction(
                schedule: schedule,
                sectionIndex: index,
                fractionInSection: fractionInSection
            ),
            passedStopCount: passed,
            stopsUntilAlighting: stopsUntilAlighting(section: entry.section, passed: passed),
            projectedCoordinate: match?.coordinate
                ?? interpolate(route: route, at: fractionInSection),
            isLocationDerived: isLocationDerived
        )
    }

    static func nearestSectionIndex(
        schedule: [JourneySectionSchedule],
        to coordinate: GeoCoordinate,
        horizontalAccuracy: Double?
    ) -> Int? {
        let tolerance = ActiveJourneyRules.arrivalRadius(horizontalAccuracy: horizontalAccuracy)
        let nearest = schedule.enumerated().compactMap { index, entry in
            Polyline(coordinates: entry.path).nearest(to: coordinate).map { match in
                (index: index, distance: match.distance)
            }
        }.min { $0.distance < $1.distance }

        guard let nearest, nearest.distance <= tolerance else { return nil }
        return nearest.index
    }

    /// Cuts a drawn segment in two at `fraction`, so the map can dim what is
    /// behind the traveller without dimming what is ahead.
    static func split(
        coordinates: [GeoCoordinate],
        at fraction: Double
    ) -> (traveled: [GeoCoordinate], remaining: [GeoCoordinate]) {
        guard coordinates.count >= 2 else { return ([], coordinates) }
        let clamped = min(max(0, fraction), 1)
        if clamped <= 0 { return ([], coordinates) }
        if clamped >= 1 { return (coordinates, []) }

        let route = Polyline(coordinates: coordinates)
        guard route.length > 0, let cut = route.point(atFraction: clamped) else {
            return ([], coordinates)
        }

        // The cut can land exactly on a vertex; adding it again would put a
        // duplicate point in both halves.
        var traveled = Array(coordinates.prefix(cut.vertexIndex + 1))
        if traveled.last != cut.coordinate { traveled.append(cut.coordinate) }

        var remaining = Array(coordinates.suffix(from: cut.vertexIndex + 1))
        if remaining.first != cut.coordinate { remaining.insert(cut.coordinate, at: 0) }

        return (traveled, remaining)
    }

    // MARK: - Time

    private static func fraction(of date: Date, between start: Date, and end: Date) -> Double {
        let span = end.timeIntervalSince(start)
        guard span > 0 else { return date >= end ? 1 : 0 }
        return min(max(0, date.timeIntervalSince(start) / span), 1)
    }

    private static func overallFraction(
        schedule: [JourneySectionSchedule],
        sectionIndex: Int,
        fractionInSection: Double
    ) -> Double {
        let durations = schedule.map { max(0, $0.endsAt.timeIntervalSince($0.startsAt)) }
        let total = durations.reduce(0, +)
        guard total > 0 else {
            return Double(sectionIndex) / Double(max(1, schedule.count))
        }
        let elapsed = durations.prefix(sectionIndex).reduce(0, +)
            + durations[sectionIndex] * fractionInSection
        return min(max(0, elapsed / total), 1)
    }

    // MARK: - Stops

    private static func passedStopCount(
        section: JourneySection,
        route: Polyline,
        fractionInSection: Double,
        isLocationDerived: Bool,
        at date: Date
    ) -> Int {
        guard section.kind == .transit, section.stops.count > 1 else { return 0 }
        let calls = section.stops.dropFirst()

        // With a fix we know where the vehicle is; without one the stop's own
        // timetable beats a linear interpolation over an unevenly spaced line.
        guard isLocationDerived, route.length > 0 else {
            return calls.count { stop in
                guard let time = stop.arrivalAt ?? stop.departureAt else { return false }
                return time <= date
            }
        }

        return calls.count { stop in
            guard let stopFraction = route.fraction(nearest: stop.coordinate) else { return false }
            return stopFraction <= fractionInSection
        }
    }

    private static func stopsUntilAlighting(section: JourneySection, passed: Int) -> Int? {
        guard section.kind == .transit, section.stops.count > 1 else { return nil }
        return max(0, section.stops.count - 1 - passed)
    }

    // MARK: - Geometry

    private static func project(
        coordinate: GeoCoordinate,
        onto route: Polyline,
        tolerance: Double
    ) -> (fraction: Double, coordinate: GeoCoordinate)? {
        guard let match = route.nearest(to: coordinate), match.distance <= tolerance else {
            return nil
        }
        return (match.fraction, match.coordinate)
    }

    private static func interpolate(route: Polyline, at fraction: Double) -> GeoCoordinate? {
        route.point(atFraction: min(max(0, fraction), 1))?.coordinate
    }
}

/// Planar helper over a journey segment, in `MKMapPoint` space.
///
/// Distances are asked back from MapKit in metres, so the flat projection only
/// ever serves to find *where* on the line a point falls, never how far apart
/// two coordinates really are.
private struct Polyline {
    let points: [MKMapPoint]
    /// Cumulative distance in metres from the first vertex.
    let cumulative: [Double]

    var length: Double { cumulative.last ?? 0 }

    init(coordinates: [GeoCoordinate]) {
        let points = coordinates.map { MKMapPoint($0.clLocationCoordinate) }
        self.points = points

        var running = 0.0
        var cumulative: [Double] = points.isEmpty ? [] : [0]
        for index in points.indices.dropFirst() {
            running += points[index - 1].distance(to: points[index])
            cumulative.append(running)
        }
        self.cumulative = cumulative
    }

    func nearest(to coordinate: GeoCoordinate) -> (distance: Double, fraction: Double, coordinate: GeoCoordinate)? {
        guard points.count >= 2, length > 0 else { return nil }
        let query = MKMapPoint(coordinate.clLocationCoordinate)

        var best: (distance: Double, fraction: Double, point: MKMapPoint)?
        for index in points.indices.dropFirst() {
            let start = points[index - 1]
            let end = points[index]
            let projected = Polyline.nearestPoint(to: query, from: start, to: end)
            let distance = query.distance(to: projected)
            if let best, distance >= best.distance { continue }

            let travelled = cumulative[index - 1] + start.distance(to: projected)
            best = (distance, min(max(0, travelled / length), 1), projected)
        }

        guard let best else { return nil }
        return (best.distance, best.fraction, best.point.coordinate.geoCoordinate)
    }

    /// Closed-form projection of a point onto a segment.
    ///
    /// `TransitRouteLayout` has the same six lines, but behind a `private
    /// extension` scoped to the network-bundling engine; widening that access
    /// to serve journeys would couple two unrelated concerns.
    static func nearestPoint(to point: MKMapPoint, from start: MKMapPoint, to end: MKMapPoint) -> MKMapPoint {
        let deltaX = end.x - start.x
        let deltaY = end.y - start.y
        let lengthSquared = deltaX * deltaX + deltaY * deltaY
        guard lengthSquared > 0 else { return start }

        let projection = ((point.x - start.x) * deltaX + (point.y - start.y) * deltaY) / lengthSquared
        let ratio = min(max(0, projection), 1)
        return MKMapPoint(x: start.x + deltaX * ratio, y: start.y + deltaY * ratio)
    }

    func fraction(nearest coordinate: GeoCoordinate) -> Double? {
        nearest(to: coordinate)?.fraction
    }

    func point(atFraction fraction: Double) -> (vertexIndex: Int, coordinate: GeoCoordinate)? {
        guard points.count >= 2, length > 0 else { return nil }
        let target = length * min(max(0, fraction), 1)

        for index in points.indices.dropFirst() where cumulative[index] >= target {
            let segmentLength = cumulative[index] - cumulative[index - 1]
            let ratio = segmentLength > 0 ? (target - cumulative[index - 1]) / segmentLength : 0
            let start = points[index - 1]
            let end = points[index]
            let interpolated = MKMapPoint(
                x: start.x + (end.x - start.x) * ratio,
                y: start.y + (end.y - start.y) * ratio
            )
            return (index - 1, interpolated.coordinate.geoCoordinate)
        }

        return (points.count - 2, points[points.count - 1].coordinate.geoCoordinate)
    }
}

private extension CLLocationCoordinate2D {
    var geoCoordinate: GeoCoordinate {
        GeoCoordinate(latitude: latitude, longitude: longitude)
    }
}
