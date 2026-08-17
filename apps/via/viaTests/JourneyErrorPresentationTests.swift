import XCTest
@testable import Via

final class JourneyErrorPresentationTests: XCTestCase {
    func testUnauthorizedJourneyErrorExplainsThatTheSessionMustBeRestored() {
        let presentation = JourneyErrorPresentation(error: .unauthorized)

        XCTAssertEqual(presentation.title, "Session expirée")
        XCTAssertEqual(
            presentation.message,
            "Reconnecte-toi avec Apple, puis réessaie."
        )
        XCTAssertEqual(
            presentation.systemImage,
            "person.crop.circle.badge.exclamationmark"
        )
    }
}
