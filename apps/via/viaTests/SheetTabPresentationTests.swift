import XCTest
@testable import Via

final class SheetTabPresentationTests: XCTestCase {
    func testCompactJourneyOnlyAppearsForCollapsedActiveJourneySheet() {
        XCTAssertTrue(
            SheetTabPresentation.showsCompactContent(
                isEligible: true,
                measuredContentProgress: 0
            )
        )
        XCTAssertFalse(
            SheetTabPresentation.showsCompactContent(
                isEligible: true,
                measuredContentProgress: 0.42
            )
        )
        XCTAssertFalse(
            SheetTabPresentation.showsCompactContent(
                isEligible: false,
                measuredContentProgress: 0
            )
        )
    }

    func testEachCollapsedDetentScoresNoContentProgress() {
        for hasCompactContent in [true, false] {
            XCTAssertEqual(
                SheetTabDetents.contentProgress(
                    sheetHeight: SheetTabDetents.collapsedHeight(hasCompactContent: hasCompactContent),
                    hasCompactContent: hasCompactContent
                ),
                0,
                "resting collapsed must hide the tab content, compact: \(hasCompactContent)"
            )
        }
    }

    func testTabContentFadesInAsTheSheetGrowsPastItsCollapsedHeight() {
        let collapsed = SheetTabDetents.collapsedHeight(hasCompactContent: true)

        XCTAssertEqual(
            SheetTabDetents.contentProgress(sheetHeight: collapsed + 85, hasCompactContent: true),
            0.5,
            accuracy: 0.001
        )
        XCTAssertEqual(
            SheetTabDetents.contentProgress(sheetHeight: collapsed + 400, hasCompactContent: true),
            1
        )
    }

    func testCompactJourneyContentHidesTabNavigationContent() {
        XCTAssertEqual(
            SheetTabPresentation.contentVisibilityProgress(
                measuredProgress: 0,
                isCompactVisible: true
            ),
            0
        )
    }

    func testTabNavigationContentFollowsMeasuredSheetProgressWithoutCompactContent() {
        XCTAssertEqual(
            SheetTabPresentation.contentVisibilityProgress(
                measuredProgress: 0.42,
                isCompactVisible: false
            ),
            0.42
        )
    }

    func testJourneyDetailPeekKeepsSummaryHeaderAndActionsVisible() {
        XCTAssertEqual(JourneySheetDetents.peekHeight(isGuiding: false), 240)
        XCTAssertEqual(
            JourneySheetDetents.peekHeight(isGuiding: true),
            SheetTabDetents.collapsedHeight(hasCompactContent: true)
        )
    }
}
