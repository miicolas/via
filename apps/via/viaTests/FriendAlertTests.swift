import XCTest
@testable import Via

final class FriendAlertTests: XCTestCase {
    func testAlertLevelsExposeTheFourReferenceChoices() {
        XCTAssertEqual(
            FriendAlertLevel.allCases,
            [.none, .justLanded, .basics, .everything]
        )
        XCTAssertTrue(FriendAlertLevel.allCases.allSatisfy { !$0.explanation.isEmpty })
    }
}
