import XCTest
@testable import Via

final class StationPeakBadgeTests: XCTestCase {
    func testAccessibilityValueNamesTheTransferStationAndPeakLevel() {
        let badge = StationPeakBadge(
            peak: StationPeak(
                ratio: 0.92,
                level: .peak,
                label: "heure la plus chargée",
                stationName: "Châtelet"
            )
        )

        XCTAssertEqual(badge.accessibilityValue, "Châtelet, heure la plus chargée")
    }

    func testAccessibilityValueStillDescribesAStationBadgeWithoutAStationName() {
        let badge = StationPeakBadge(
            peak: StationPeak(
                ratio: 0.58,
                level: .moderate,
                label: "fréquentation soutenue"
            )
        )

        XCTAssertEqual(badge.accessibilityValue, "fréquentation soutenue")
    }
}
