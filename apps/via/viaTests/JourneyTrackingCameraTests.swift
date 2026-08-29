import MapKit
import SwiftUI
import XCTest
@testable import Via

final class JourneyTrackingCameraTests: XCTestCase {
  func testWalkCameraFacesTheRouteAndKeepsTheTravellerBehindItsCenter() throws {
    let origin = GeoCoordinate(latitude: 48.8566, longitude: 2.3522)
    let destination = GeoCoordinate(latitude: 48.8566, longitude: 2.3622)
    let camera = try XCTUnwrap(
      JourneyTrackingCamera(
        section: makeSection(kind: .walk, from: origin, to: destination),
        userCoordinate: origin
      )
    )

    XCTAssertEqual(camera.heading, 90, accuracy: 0.5)
    XCTAssertEqual(origin.metersAway(from: camera.centerCoordinate), 55, accuracy: 1)
    XCTAssertEqual(camera.distance, 420)
    XCTAssertEqual(camera.pitch, 62)
  }

  func testBikeCameraLooksFurtherAheadThanWalkingCamera() throws {
    let origin = GeoCoordinate(latitude: 48.8566, longitude: 2.3522)
    let destination = GeoCoordinate(latitude: 48.8566, longitude: 2.3722)
    let walk = try XCTUnwrap(
      JourneyTrackingCamera(
        section: makeSection(kind: .walk, from: origin, to: destination),
        userCoordinate: origin
      )
    )
    let bike = try XCTUnwrap(
      JourneyTrackingCamera(
        section: makeSection(kind: .bike, from: origin, to: destination),
        userCoordinate: origin
      )
    )

    XCTAssertGreaterThan(
      origin.metersAway(from: bike.centerCoordinate),
      origin.metersAway(from: walk.centerCoordinate)
    )
    XCTAssertGreaterThan(bike.distance, walk.distance)
  }

  func testMissingGeometryFallsBackToTheSectionEndpoints() throws {
    let origin = GeoCoordinate(latitude: 48.8566, longitude: 2.3522)
    let destination = GeoCoordinate(latitude: 48.8666, longitude: 2.3522)
    let camera = try XCTUnwrap(
      JourneyTrackingCamera(
        section: makeSection(
          kind: .walk,
          from: origin,
          to: destination,
          geometry: []
        ),
        userCoordinate: origin
      )
    )

    XCTAssertEqual(camera.heading, 0, accuracy: 0.5)
  }

  func testTransitAndDegeneratePedestrianLegsDoNotOfferA3DCamera() {
    let origin = GeoCoordinate(latitude: 48.8566, longitude: 2.3522)
    let destination = GeoCoordinate(latitude: 48.8666, longitude: 2.3622)

    XCTAssertNil(
      JourneyTrackingCamera(
        section: makeSection(kind: .transit, from: origin, to: destination),
        userCoordinate: origin
      )
    )
    XCTAssertNil(
      JourneyTrackingCamera(
        section: makeSection(kind: .walk, from: origin, to: origin, geometry: []),
        userCoordinate: origin
      )
    )
  }

  func testReduceMotionKeepsLocationFollowWithoutRotationOrDepth() throws {
    let origin = GeoCoordinate(latitude: 48.8566, longitude: 2.3522)
    let destination = GeoCoordinate(latitude: 48.8566, longitude: 2.3622)
    let trackingCamera = try XCTUnwrap(
      JourneyTrackingCamera(
        section: makeSection(kind: .walk, from: origin, to: destination),
        userCoordinate: origin
      )
    )

    let reducedCamera = trackingCamera.mapCamera(reducesMotion: true)

    XCTAssertEqual(reducedCamera.centerCoordinate.latitude, origin.latitude, accuracy: 0.000_001)
    XCTAssertEqual(reducedCamera.centerCoordinate.longitude, origin.longitude, accuracy: 0.000_001)
    XCTAssertEqual(reducedCamera.heading, 0)
    XCTAssertEqual(reducedCamera.pitch, 0)
  }

  private func makeSection(
    kind: JourneySection.Kind,
    from origin: GeoCoordinate,
    to destination: GeoCoordinate,
    geometry: [GeoCoordinate]? = nil
  ) -> JourneySection {
    JourneySection(
      id: "camera:\(kind.rawValue)",
      kind: kind,
      durationSeconds: 300,
      from: JourneyPlace(name: "Départ", coordinate: origin),
      to: JourneyPlace(name: "Arrivée", coordinate: destination),
      departureAt: nil,
      arrivalAt: nil,
      geometry: geometry ?? [origin, destination],
      route: nil,
      direction: nil,
      platform: nil,
      stops: []
    )
  }
}
