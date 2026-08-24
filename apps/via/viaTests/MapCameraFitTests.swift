import MapKit
import XCTest
@testable import Via

final class MapCameraFitTests: XCTestCase {
    func testResultsFillingTheFrameDoNotMoveTheCamera() {
        let current = region(spanMeters: 2_000)
        let bounds = bounds(spanMeters: 1_500)

        XCTAssertNil(MapCameraFit.fittedRegion(for: bounds, in: current))
    }

    func testResultsClusteredWellInsideTheFrameTightenIt() {
        let current = region(spanMeters: 40_000)
        let bounds = bounds(spanMeters: 1_200)

        guard let fitted = MapCameraFit.fittedRegion(for: bounds, in: current) else {
            return XCTFail("A decisive tightening was expected")
        }
        XCTAssertLessThan(fitted.span.latitudeDelta, current.span.latitudeDelta)
        XCTAssertEqual(fitted.center.latitude, 48.85, accuracy: 0.001)
    }

    /// The failure this rule exists to prevent: framing a region-wide result
    /// would zoom *out* and put the names further away than they already were.
    func testAWideResultNeverWidensTheFrame() {
        let current = region(spanMeters: 3_000)
        let bounds = bounds(spanMeters: 80_000)

        XCTAssertNil(MapCameraFit.fittedRegion(for: bounds, in: current))
    }

    func testASingleResultKeepsAReadableSpanRatherThanACornerOfStreet() {
        let current = region(spanMeters: 60_000)
        let point = GeoBounds(
            minLatitude: 48.85,
            maxLatitude: 48.85,
            minLongitude: 2.35,
            maxLongitude: 2.35
        )

        guard let fitted = MapCameraFit.fittedRegion(for: point, in: current) else {
            return XCTFail("A single result was expected to be framed")
        }
        XCTAssertEqual(
            fitted.span.latitudeDelta * 111_000,
            MapCameraFit.minimumSpanMeters,
            accuracy: 1
        )
    }

    /// Below the floor the tightening test is applied to the *floored* span, so
    /// a single result in a barely-wider frame still leaves the camera alone.
    func testASingleResultInANearbyFrameLeavesTheCameraAlone() {
        let current = region(spanMeters: MapCameraFit.minimumSpanMeters * 2)
        let point = GeoBounds(
            minLatitude: 48.85,
            maxLatitude: 48.85,
            minLongitude: 2.35,
            maxLongitude: 2.35
        )

        XCTAssertNil(MapCameraFit.fittedRegion(for: point, in: current))
    }

    private func region(spanMeters: Double) -> MKCoordinateRegion {
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 48.85, longitude: 2.35),
            span: MKCoordinateSpan(
                latitudeDelta: spanMeters / 111_000,
                longitudeDelta: spanMeters / 111_000
            )
        )
    }

    private func bounds(spanMeters: Double) -> GeoBounds {
        let delta = spanMeters / 111_000 / 2
        return GeoBounds(
            minLatitude: 48.85 - delta,
            maxLatitude: 48.85 + delta,
            minLongitude: 2.35 - delta,
            maxLongitude: 2.35 + delta
        )
    }
}
