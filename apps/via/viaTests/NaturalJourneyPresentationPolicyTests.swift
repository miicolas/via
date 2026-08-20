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

    func testSystemFailureGuidanceDoesNotBlameTheRequestOrInventADownloadState() {
        let guidance = NaturalJourneyUnavailableGuidance.systemUnavailable

        XCTAssertEqual(guidance.title, "Apple Intelligence ne répond pas")
        XCTAssertEqual(
            guidance.message,
            "Le modèle est activé, mais iOS n’a pas pu terminer cette demande. Ta phrase n’est pas en cause.",
        )
        XCTAssertEqual(
            guidance.instructions.map(\.systemImage),
            ["arrow.down.circle", "gearshape", "wifi"],
        )
    }
}
