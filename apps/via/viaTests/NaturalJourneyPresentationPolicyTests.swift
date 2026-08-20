@testable import Via
import XCTest

final class NaturalJourneyPresentationPolicyTests: XCTestCase {
    func testOnlyTheInputStateExpandsTheSharedMapSheet() {
        XCTAssertFalse(NaturalJourneyPresentationPolicy.expandsForInput(.onboarding))
        XCTAssertTrue(NaturalJourneyPresentationPolicy.expandsForInput(.input))
        XCTAssertFalse(NaturalJourneyPresentationPolicy.expandsForInput(.loading))
    }

    func testBothEntryButtonsShareTheRequiredVoiceOverCopy() {
        XCTAssertEqual(
            NaturalJourneyPresentationPolicy.entryAccessibilityLabel,
            "Rechercher avec Apple Intelligence",
        )
        XCTAssertEqual(
            NaturalJourneyPresentationPolicy.entryAccessibilityHint,
            "Décris ton trajet dans une phrase",
        )
    }
}
