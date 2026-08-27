import MapKit
import XCTest
@testable import Via

final class JourneyNavigationCameraTests: XCTestCase {
  func testCameraLooksAheadAlongTheCurrentJourneySection() throws {
    let journey = JourneyResult.mapPreview.journeys[0]
    let presentation = JourneyMapPresentation(journey: journey)
    let segment = try XCTUnwrap(presentation.segments.first(where: {
      $0.coordinates.count >= 2 && !$0.isStationary
    }))
    let position = try XCTUnwrap(segment.coordinates.first)
    let progress = JourneyProgress(
      sectionIndex: segment.sectionIndex,
      fractionInSection: 0,
      overallFraction: 0,
      passedStopCount: 0,
      stopsUntilAlighting: nil,
      projectedCoordinate: position,
      isLocationDerived: true
    )

    let camera = try XCTUnwrap(JourneyNavigationCamera.resolve(
      presentation: presentation,
      progress: progress
    ))

    let lookAheadDistance = MKMapPoint(position.clLocationCoordinate).distance(
      to: MKMapPoint(camera.center.clLocationCoordinate)
    )
    XCTAssertGreaterThan(lookAheadDistance, 0)
    XCTAssertLessThanOrEqual(lookAheadDistance, segment.isPedestrian ? 90.5 : 180.5)
    XCTAssertTrue((0..<360).contains(camera.heading))
    XCTAssertEqual(camera.distance, segment.isPedestrian ? 650 : 1_100)
  }

  func testCameraUsesTheSameRouteDirectionForEstimatedProgress() throws {
    let journey = JourneyResult.mapPreview.journeys[0]
    let presentation = JourneyMapPresentation(journey: journey)
    let segment = try XCTUnwrap(presentation.segments.first(where: {
      $0.coordinates.count >= 2 && !$0.isStationary
    }))
    let position = try XCTUnwrap(segment.coordinates.first)

    func camera(isLocationDerived: Bool) throws -> JourneyNavigationCamera {
      try XCTUnwrap(JourneyNavigationCamera.resolve(
        presentation: presentation,
        progress: JourneyProgress(
          sectionIndex: segment.sectionIndex,
          fractionInSection: 0,
          overallFraction: 0,
          passedStopCount: 0,
          stopsUntilAlighting: nil,
          projectedCoordinate: position,
          isLocationDerived: isLocationDerived
        )
      ))
    }

    let live = try camera(isLocationDerived: true)
    let estimated = try camera(isLocationDerived: false)

    XCTAssertEqual(estimated.center, live.center)
    XCTAssertEqual(estimated.heading, live.heading, accuracy: 0.001)
  }
}
