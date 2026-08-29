import MapKit
import SwiftUI

/// The route-aware camera used while a traveller follows a self-powered leg.
///
/// GPS course is especially noisy at walking speed. The camera therefore gets
/// its heading from the planned polyline, while its centre stays relative to
/// the native user location so an off-route fix never pushes the blue dot out
/// of view.
struct JourneyTrackingCamera: Sendable, Equatable {
  let userCoordinate: GeoCoordinate
  let centerCoordinate: GeoCoordinate
  let heading: Double
  let distance: Double
  let pitch: Double

  init?(section: JourneySection, userCoordinate: GeoCoordinate) {
    guard let profile = Profile(section.kind),
          let path = RoutePath(section: section),
          let heading = path.heading(
            nearestTo: userCoordinate,
            lookingAhead: profile.directionLookAhead
          )
    else { return nil }

    self.userCoordinate = userCoordinate
    centerCoordinate = Self.coordinate(
      from: userCoordinate,
      distance: profile.centerLookAhead,
      heading: heading
    )
    self.heading = heading
    distance = profile.cameraDistance
    pitch = profile.pitch
  }

  /// Reduce Motion keeps the useful location follow but removes the automatic
  /// rotation, depth change, and ahead-of-user camera offset.
  func mapCamera(reducesMotion: Bool) -> MapCamera {
    if reducesMotion {
      return MapCamera(
        centerCoordinate: userCoordinate.clLocationCoordinate,
        distance: distance,
        heading: 0,
        pitch: 0
      )
    }

    return MapCamera(
      centerCoordinate: centerCoordinate.clLocationCoordinate,
      distance: distance,
      heading: heading,
      pitch: pitch
    )
  }

  private static func coordinate(
    from origin: GeoCoordinate,
    distance: Double,
    heading: Double
  ) -> GeoCoordinate {
    let earthRadius = 6_371_000.0
    let angularDistance = distance / earthRadius
    let bearing = heading * .pi / 180
    let latitude = origin.latitude * .pi / 180
    let longitude = origin.longitude * .pi / 180

    let targetLatitude = asin(
      sin(latitude) * cos(angularDistance)
        + cos(latitude) * sin(angularDistance) * cos(bearing)
    )
    let targetLongitude = longitude + atan2(
      sin(bearing) * sin(angularDistance) * cos(latitude),
      cos(angularDistance) - sin(latitude) * sin(targetLatitude)
    )

    return GeoCoordinate(
      latitude: targetLatitude * 180 / .pi,
      longitude: Self.normalizedLongitude(targetLongitude * 180 / .pi)
    )
  }

  private static func normalizedLongitude(_ longitude: Double) -> Double {
    (longitude + 540).truncatingRemainder(dividingBy: 360) - 180
  }
}

private extension JourneyTrackingCamera {
  struct Profile {
    let centerLookAhead: Double
    let directionLookAhead: Double
    let cameraDistance: Double
    let pitch: Double

    init?(_ sectionKind: JourneySection.Kind) {
      switch sectionKind {
      case .walk, .transfer:
        centerLookAhead = 55
        directionLookAhead = 35
        cameraDistance = 420
        pitch = 62
      case .bike:
        centerLookAhead = 95
        directionLookAhead = 65
        cameraDistance = 650
        pitch = 58
      case .wait, .transit:
        return nil
      }
    }
  }

  struct RoutePath {
    struct Projection {
      let point: MKMapPoint
      let segmentIndex: Int
      let progress: Double
      let distanceFromQuery: Double
    }

    let points: [MKMapPoint]
    let segmentLengths: [Double]
    let totalLength: Double

    init?(section: JourneySection) {
      let routeCoordinates = section.geometry.count >= 2
        ? section.geometry
        : [section.from.coordinate, section.to.coordinate]

      let routePoints = Self.distinctPoints(routeCoordinates)
      let endpointPoints = Self.distinctPoints([
        section.from.coordinate,
        section.to.coordinate,
      ])
      let resolvedPoints = routePoints.count >= 2 ? routePoints : endpointPoints
      guard resolvedPoints.count >= 2 else { return nil }

      let lengths = resolvedPoints.indices.dropLast().map { index in
        resolvedPoints[index].distance(to: resolvedPoints[index + 1])
      }
      guard lengths.contains(where: { $0 > 0 }) else { return nil }

      points = resolvedPoints
      segmentLengths = lengths
      totalLength = lengths.reduce(0, +)
    }

    func heading(nearestTo coordinate: GeoCoordinate, lookingAhead distance: Double) -> Double? {
      guard let projection = nearestProjection(to: coordinate) else { return nil }
      let target = point(at: min(totalLength, projection.progress + distance))

      if projection.point.distance(to: target) > 0.5 {
        return Self.bearing(from: projection.point.coordinate, to: target.coordinate)
      }

      let start = points[projection.segmentIndex]
      let end = points[projection.segmentIndex + 1]
      guard start.distance(to: end) > 0.5 else { return nil }
      return Self.bearing(from: start.coordinate, to: end.coordinate)
    }

    private func nearestProjection(to coordinate: GeoCoordinate) -> Projection? {
      let query = MKMapPoint(coordinate.clLocationCoordinate)
      var travelled = 0.0
      var nearest: Projection?

      for index in segmentLengths.indices {
        let start = points[index]
        let end = points[index + 1]
        let ratio = Self.projectionRatio(of: query, from: start, to: end)
        let projected = MKMapPoint(
          x: start.x + (end.x - start.x) * ratio,
          y: start.y + (end.y - start.y) * ratio
        )
        let candidate = Projection(
          point: projected,
          segmentIndex: index,
          progress: travelled + segmentLengths[index] * ratio,
          distanceFromQuery: query.distance(to: projected)
        )
        if nearest == nil || candidate.distanceFromQuery < nearest!.distanceFromQuery {
          nearest = candidate
        }
        travelled += segmentLengths[index]
      }

      return nearest
    }

    private func point(at progress: Double) -> MKMapPoint {
      var travelled = 0.0
      for index in segmentLengths.indices {
        let segmentLength = segmentLengths[index]
        let segmentEnd = travelled + segmentLength
        if progress <= segmentEnd || index == segmentLengths.indices.last {
          guard segmentLength > 0 else { return points[index + 1] }
          let ratio = min(max((progress - travelled) / segmentLength, 0), 1)
          let start = points[index]
          let end = points[index + 1]
          return MKMapPoint(
            x: start.x + (end.x - start.x) * ratio,
            y: start.y + (end.y - start.y) * ratio
          )
        }
        travelled = segmentEnd
      }
      return points.last!
    }

    private static func distinctPoints(_ coordinates: [GeoCoordinate]) -> [MKMapPoint] {
      coordinates.reduce(into: []) { result, coordinate in
        let point = MKMapPoint(coordinate.clLocationCoordinate)
        if result.last.map({ $0.distance(to: point) > 0.05 }) ?? true {
          result.append(point)
        }
      }
    }

    private static func projectionRatio(
      of point: MKMapPoint,
      from start: MKMapPoint,
      to end: MKMapPoint
    ) -> Double {
      let deltaX = end.x - start.x
      let deltaY = end.y - start.y
      let lengthSquared = deltaX * deltaX + deltaY * deltaY
      guard lengthSquared > 0 else { return 0 }
      let projection = ((point.x - start.x) * deltaX + (point.y - start.y) * deltaY)
        / lengthSquared
      return min(max(projection, 0), 1)
    }

    private static func bearing(
      from origin: CLLocationCoordinate2D,
      to destination: CLLocationCoordinate2D
    ) -> Double {
      let originLatitude = origin.latitude * .pi / 180
      let destinationLatitude = destination.latitude * .pi / 180
      let longitudeDelta = (destination.longitude - origin.longitude) * .pi / 180
      let y = sin(longitudeDelta) * cos(destinationLatitude)
      let x = cos(originLatitude) * sin(destinationLatitude)
        - sin(originLatitude) * cos(destinationLatitude) * cos(longitudeDelta)
      let degrees = atan2(y, x) * 180 / .pi
      return (degrees + 360).truncatingRemainder(dividingBy: 360)
    }
  }
}
