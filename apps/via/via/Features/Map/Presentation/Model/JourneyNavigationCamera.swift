import MapKit
import SwiftUI

/// A navigation-style camera resolved from the journey route rather than from
/// network availability. Keeping the descriptor value-only makes the geometry
/// independently testable from SwiftUI's `Map`.
struct JourneyNavigationCamera: Sendable, Hashable {
  let center: GeoCoordinate
  let distance: Double
  let heading: Double
  let pitch: Double

  var mapCamera: MapCamera {
    MapCamera(
      centerCoordinate: center.clLocationCoordinate,
      distance: distance,
      heading: heading,
      pitch: pitch
    )
  }

  static func resolve(
    presentation: JourneyMapPresentation,
    progress: JourneyProgress
  ) -> JourneyNavigationCamera? {
    guard let position = progress.projectedCoordinate,
          let segment = presentation.segments.first(where: {
            $0.sectionIndex == progress.sectionIndex
          })
    else { return nil }

    let remaining = JourneyProgressProjector.split(
      coordinates: segment.coordinates,
      at: progress.fractionInSection
    ).remaining
    let forwardPath = [position] + remaining.drop(while: {
      MKMapPoint($0.clLocationCoordinate).distance(
        to: MKMapPoint(position.clLocationCoordinate)
      ) < 2
    })
    let fallbackPath = Array(segment.coordinates.suffix(2))
    let directionPath = forwardPath.count >= 2 ? forwardPath : fallbackPath
    let isPedestrian = segment.isPedestrian
    let lookAheadDistance = isPedestrian ? 90.0 : 180.0

    return JourneyNavigationCamera(
      center: point(along: directionPath, distance: lookAheadDistance) ?? position,
      distance: isPedestrian ? 650 : 1_100,
      heading: heading(along: directionPath) ?? 0,
      pitch: isPedestrian ? 35 : 45
    )
  }

  private static func point(
    along coordinates: [GeoCoordinate],
    distance targetDistance: Double
  ) -> GeoCoordinate? {
    guard let first = coordinates.first else { return nil }
    guard coordinates.count >= 2 else { return first }

    var remainingDistance = max(0, targetDistance)
    for index in coordinates.indices.dropFirst() {
      let start = MKMapPoint(coordinates[index - 1].clLocationCoordinate)
      let end = MKMapPoint(coordinates[index].clLocationCoordinate)
      let segmentDistance = start.distance(to: end)
      guard segmentDistance > 0 else { continue }
      if remainingDistance <= segmentDistance {
        let fraction = remainingDistance / segmentDistance
        return GeoCoordinate(
          latitude: start.coordinate.latitude
            + (end.coordinate.latitude - start.coordinate.latitude) * fraction,
          longitude: start.coordinate.longitude
            + (end.coordinate.longitude - start.coordinate.longitude) * fraction
        )
      }
      remainingDistance -= segmentDistance
    }

    return coordinates.last
  }

  private static func heading(along coordinates: [GeoCoordinate]) -> Double? {
    guard let first = coordinates.first else { return nil }
    let start = MKMapPoint(first.clLocationCoordinate)
    guard let end = coordinates.dropFirst().lazy
      .map({ MKMapPoint($0.clLocationCoordinate) })
      .first(where: { start.distance(to: $0) >= 2 })
    else { return nil }

    let radians = atan2(end.x - start.x, start.y - end.y)
    let degrees = radians * 180 / .pi
    return degrees >= 0 ? degrees : degrees + 360
  }
}
