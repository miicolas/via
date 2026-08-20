import XCTest
@testable import Via

final class SheetTabPresentationTests: XCTestCase {
    func testJourneyAccessoryOnlyAppearsForCollapsedActiveJourneySheet() {
        XCTAssertTrue(
            SheetTabPresentation.showsAccessory(
                isEligible: true,
                measuredContentProgress: 0
            )
        )
        XCTAssertFalse(
            SheetTabPresentation.showsAccessory(
                isEligible: true,
                measuredContentProgress: 0.42
            )
        )
        XCTAssertFalse(
            SheetTabPresentation.showsAccessory(
                isEligible: false,
                measuredContentProgress: 0
            )
        )
    }

    func testCompactJourneyAccessoryHidesTabNavigationContent() {
        XCTAssertEqual(
            SheetTabPresentation.contentVisibilityProgress(
                measuredProgress: 0,
                isAccessoryVisible: true
            ),
            0
        )
    }

    func testTabNavigationContentFollowsMeasuredSheetProgressWithoutAccessory() {
        XCTAssertEqual(
            SheetTabPresentation.contentVisibilityProgress(
                measuredProgress: 0.42,
                isAccessoryVisible: false
            ),
            0.42
        )
    }
}
