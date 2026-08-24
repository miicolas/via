import XCTest
@testable import Via

final class NetworkViewportAnnotationTests: XCTestCase {
  func testOverviewUsesCompactAnnotationsAndCloseZoomUsesDetails() {
    XCTAssertTrue(viewport(spanMeters: 12_000).usesCompactStationAnnotations)
    XCTAssertTrue(viewport(spanMeters: 1_400).usesCompactStationAnnotations)
    XCTAssertFalse(viewport(spanMeters: 800).usesCompactStationAnnotations)
  }

  func testNearbyRadiusMustCoverEveryViewportCorner() {
    XCTAssertTrue(viewport(spanMeters: 2_000).fitsInside(radiusMeters: 2_000))
    XCTAssertFalse(viewport(spanMeters: 4_000).fitsInside(radiusMeters: 2_000))
  }

  private func viewport(spanMeters: Double) -> NetworkViewport {
    NetworkViewport(
      center: GeoCoordinate(latitude: 48.85, longitude: 2.35),
      latitudeDelta: spanMeters / 111_000,
      longitudeDelta: spanMeters / 111_000,
      width: 390,
      height: 844
    )
  }
}
