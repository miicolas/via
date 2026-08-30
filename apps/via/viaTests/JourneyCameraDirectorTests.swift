import MapKit
import SwiftUI
import XCTest
@testable import Via

@MainActor
final class JourneyCameraDirectorTests: XCTestCase {
    private let paris = GeoCoordinate(latitude: 48.8566, longitude: 2.3522)
    private let eastOfParis = GeoCoordinate(latitude: 48.8566, longitude: 2.3622)

    // MARK: - Opening

    func testCachedFixOpensOnTheTravellerImmediately() throws {
        let director = JourneyCameraDirector(openingCoordinate: eastOfParis)

        XCTAssertTrue(director.hasResolvedOpeningLocation)
        let region = try XCTUnwrap(director.position.region)
        XCTAssertEqual(region.center.longitude, eastOfParis.longitude, accuracy: 0.000_1)
    }

    func testFirstFixResolvesTheOpeningCameraOnce() throws {
        let director = JourneyCameraDirector(openingCoordinate: nil)
        XCTAssertFalse(director.hasResolvedOpeningLocation)
        XCTAssertTrue(MapOpeningCamera.isUntouchedFallback(try XCTUnwrap(director.position.region)))

        director.locationChanged(eastOfParis, tracking: nil, reducesMotion: true)

        XCTAssertTrue(director.hasResolvedOpeningLocation)
        let region = try XCTUnwrap(director.position.region)
        XCTAssertEqual(region.center.longitude, eastOfParis.longitude, accuracy: 0.000_1)

        // A later fix never jumps the camera again.
        director.locationChanged(paris, tracking: nil, reducesMotion: true)
        XCTAssertEqual(
            try XCTUnwrap(director.position.region).center.longitude,
            eastOfParis.longitude,
            accuracy: 0.000_1
        )
    }

    func testATouchedCameraKeepsTheTravellersFraming() throws {
        let director = JourneyCameraDirector(openingCoordinate: nil)
        let explored = MKCoordinateRegion(
            center: .init(latitude: 48.90, longitude: 2.40),
            latitudinalMeters: 900,
            longitudinalMeters: 900
        )
        director.position = .region(explored)

        director.locationChanged(eastOfParis, tracking: nil, reducesMotion: true)

        XCTAssertTrue(director.hasResolvedOpeningLocation)
        XCTAssertEqual(
            try XCTUnwrap(director.position.region).center.longitude,
            explored.center.longitude,
            accuracy: 0.000_1
        )
    }

    func testAFixOutsideTheServiceAreaResolvesWithoutJumping() throws {
        let director = JourneyCameraDirector(openingCoordinate: nil)
        let marseille = GeoCoordinate(latitude: 43.2965, longitude: 5.3698)

        director.locationChanged(marseille, tracking: nil, reducesMotion: true)

        XCTAssertTrue(director.hasResolvedOpeningLocation)
        XCTAssertTrue(MapOpeningCamera.isUntouchedFallback(try XCTUnwrap(director.position.region)))
    }

    // MARK: - Follow

    func testTrackingFlipsFollowAndAppliesTheRouteCamera() throws {
        let director = JourneyCameraDirector(openingCoordinate: paris)
        let tracking = try walkTracking()

        director.trackingChanged(isTracking: true, tracking: tracking, reducesMotion: false)

        XCTAssertTrue(director.followsLocation)
        XCTAssertEqual(director.position, .camera(tracking.mapCamera(reducesMotion: false)))

        director.trackingChanged(isTracking: false, tracking: nil, reducesMotion: false)
        XCTAssertFalse(director.followsLocation)
    }

    func testTravellerPanEndsFollowUntilRecenter() throws {
        let director = JourneyCameraDirector(openingCoordinate: paris)
        let tracking = try walkTracking()
        director.trackingChanged(isTracking: true, tracking: tracking, reducesMotion: false)

        director.travellerMoved()
        XCTAssertFalse(director.followsLocation)

        // A location update while the traveller holds the map must not steal it.
        director.position = .region(.paris)
        director.locationChanged(eastOfParis, tracking: tracking, reducesMotion: false)
        XCTAssertEqual(director.position, .region(.paris))

        director.recenter(tracking: tracking, reducesMotion: false)
        XCTAssertTrue(director.followsLocation)
        XCTAssertEqual(director.position, .camera(tracking.mapCamera(reducesMotion: false)))
    }

    // MARK: - Sections

    func testRailSectionsFallBackToTheJourneyOverview() throws {
        let director = JourneyCameraDirector(openingCoordinate: paris)
        director.trackingChanged(isTracking: true, tracking: nil, reducesMotion: false)
        let overview = MKMapRect(x: 1_000, y: 2_000, width: 300, height: 400)

        director.sectionChanged(tracking: nil, journeyFrame: overview, reducesMotion: false)

        XCTAssertEqual(director.position, .rect(overview))
    }

    func testPedestrianSectionsKeepTheThirdPersonCamera() throws {
        let director = JourneyCameraDirector(openingCoordinate: paris)
        let tracking = try walkTracking()
        director.trackingChanged(isTracking: true, tracking: tracking, reducesMotion: false)

        director.sectionChanged(
            tracking: tracking,
            journeyFrame: MKMapRect(x: 0, y: 0, width: 10, height: 10),
            reducesMotion: false
        )

        XCTAssertEqual(director.position, .camera(tracking.mapCamera(reducesMotion: false)))
    }

    // MARK: - Framing

    func testPresentationFramesTheJourneyOnlyWhileNotTracking() throws {
        let director = JourneyCameraDirector(openingCoordinate: paris)
        let overview = MKMapRect(x: 500, y: 600, width: 200, height: 200)

        director.presentationChanged(
            isTracking: false,
            tracking: nil,
            mapRect: overview,
            reducesMotion: false
        )
        XCTAssertEqual(director.position, .rect(overview))

        let tracking = try walkTracking()
        director.trackingChanged(isTracking: true, tracking: tracking, reducesMotion: false)
        director.presentationChanged(
            isTracking: true,
            tracking: tracking,
            mapRect: MKMapRect(x: 0, y: 0, width: 1, height: 1),
            reducesMotion: false
        )
        XCTAssertEqual(director.position, .camera(tracking.mapCamera(reducesMotion: false)))
    }

    func testFrameIgnoresAMissingRect() {
        let director = JourneyCameraDirector(openingCoordinate: paris)
        let before = director.position

        director.frame(nil)

        XCTAssertEqual(director.position, before)
    }

    func testReduceMotionResnapsTheFollowCameraWithoutRotation() throws {
        let director = JourneyCameraDirector(openingCoordinate: paris)
        let tracking = try walkTracking()
        director.trackingChanged(isTracking: true, tracking: tracking, reducesMotion: false)

        director.motionChanged(tracking: tracking, reducesMotion: true)

        XCTAssertEqual(director.position, .camera(tracking.mapCamera(reducesMotion: true)))
    }

    // MARK: - Fixtures

    private func walkTracking() throws -> JourneyTrackingCamera {
        try XCTUnwrap(
            JourneyTrackingCamera(
                section: JourneySection(
                    id: "camera:walk",
                    kind: .walk,
                    durationSeconds: 300,
                    from: JourneyPlace(name: "Départ", coordinate: paris),
                    to: JourneyPlace(name: "Arrivée", coordinate: eastOfParis),
                    departureAt: nil,
                    arrivalAt: nil,
                    geometry: [paris, eastOfParis],
                    route: nil,
                    direction: nil,
                    platform: nil,
                    stops: []
                ),
                userCoordinate: paris
            )
        )
    }
}
