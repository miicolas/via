import XCTest
@testable import Via

final class TransitLineVisibilityTests: XCTestCase {
    func testLinesKeepTheirLocalStyleThroughFifteenKilometers() {
        XCTAssertEqual(TransitLineVisibility.opacity(for: 0), 1)
        XCTAssertEqual(TransitLineVisibility.opacity(for: 15_000), 1)
        XCTAssertEqual(TransitLineVisibility.lineWidth(for: 15_000), 3)
        XCTAssertEqual(TransitLineVisibility.laneSpacing(for: 15_000), 6)
    }

    func testCityOverviewUsesACompactMutedStyle() {
        XCTAssertEqual(
            TransitLineVisibility.opacity(for: 100_000),
            0.45,
            accuracy: 0.000_000_1
        )
        XCTAssertEqual(
            TransitLineVisibility.lineWidth(for: 100_000),
            1.25,
            accuracy: 0.000_000_1
        )
        XCTAssertEqual(
            TransitLineVisibility.laneSpacing(for: 100_000),
            1.5,
            accuracy: 0.000_000_1
        )
    }

    func testRegionalOverviewCollapsesLanesAndKeepsThinLines() {
        XCTAssertEqual(TransitLineVisibility.opacity(for: 500_000), 0.18)
        XCTAssertEqual(TransitLineVisibility.lineWidth(for: 500_000), 0.75)
        XCTAssertEqual(TransitLineVisibility.laneSpacing(for: 250_000), 0)
        XCTAssertEqual(TransitLineVisibility.laneSpacing(for: 500_000), 0)
    }

    func testLinesDisappearAtEightHundredKilometers() {
        XCTAssertEqual(TransitLineVisibility.opacity(for: 800_000), 0)
        XCTAssertEqual(TransitLineVisibility.opacity(for: 900_000), 0)
    }

    func testOpacityChangesContinuouslyBetweenThresholds() {
        XCTAssertEqual(
            TransitLineVisibility.opacity(for: 57_500),
            0.725,
            accuracy: 0.000_000_1
        )
        XCTAssertEqual(
            TransitLineVisibility.opacity(for: 300_000),
            0.315,
            accuracy: 0.000_000_1
        )
        XCTAssertEqual(
            TransitLineVisibility.opacity(for: 650_000),
            0.09,
            accuracy: 0.000_000_1
        )
    }

    func testWidthAndLaneSpacingChangeContinuously() {
        XCTAssertEqual(
            TransitLineVisibility.lineWidth(for: 57_500),
            2.125,
            accuracy: 0.000_000_1
        )
        XCTAssertEqual(
            TransitLineVisibility.lineWidth(for: 300_000),
            1,
            accuracy: 0.000_000_1
        )
        XCTAssertEqual(
            TransitLineVisibility.laneSpacing(for: 57_500),
            3.75,
            accuracy: 0.000_000_1
        )
        XCTAssertEqual(
            TransitLineVisibility.laneSpacing(for: 175_000),
            0.75,
            accuracy: 0.000_000_1
        )
    }
}
