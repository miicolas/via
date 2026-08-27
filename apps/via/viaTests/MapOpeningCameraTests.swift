import MapKit
import XCTest
@testable import Via

final class MapOpeningCameraTests: XCTestCase {
    func testKnownLocationInIleDeFranceIsTheOpeningCenter() {
        let location = GeoCoordinate(latitude: 48.787, longitude: 2.455)

        let region = MapOpeningCamera.region(for: location)

        XCTAssertEqual(region.center.latitude, location.latitude, accuracy: 0.000_001)
        XCTAssertEqual(region.center.longitude, location.longitude, accuracy: 0.000_001)
        XCTAssertEqual(
            region.span.latitudeDelta * 111_000,
            MapOpeningCamera.spanMeters,
            accuracy: 2
        )
    }

    func testLocationOutsideIleDeFranceKeepsParisFallback() {
        let lyon = GeoCoordinate(latitude: 45.764, longitude: 4.836)

        let region = MapOpeningCamera.region(for: lyon)

        XCTAssertEqual(region.center.latitude, MKCoordinateRegion.paris.center.latitude)
        XCTAssertEqual(region.center.longitude, MKCoordinateRegion.paris.center.longitude)
    }

    func testMissingLocationKeepsParisFallback() {
        let region = MapOpeningCamera.region(for: nil)

        XCTAssertEqual(region.center.latitude, MKCoordinateRegion.paris.center.latitude)
        XCTAssertEqual(region.center.longitude, MKCoordinateRegion.paris.center.longitude)
    }

    func testFallbackToleranceRejectsAUserPanOrZoom() {
        var panned = MKCoordinateRegion.paris
        panned.center.latitude += 0.01
        var zoomed = MKCoordinateRegion.paris
        zoomed.span.latitudeDelta /= 2

        XCTAssertTrue(MapOpeningCamera.isUntouchedFallback(.paris))
        XCTAssertFalse(MapOpeningCamera.isUntouchedFallback(panned))
        XCTAssertFalse(MapOpeningCamera.isUntouchedFallback(zoomed))
    }
}
