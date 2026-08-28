import XCTest
@testable import Via

final class JourneyWarningPresentationTests: XCTestCase {
    func testHidesOfferAdaptationWarningWithCurlyApostrophe() {
        let warnings = [
            "adaptation de l’offre de transport",
            "Ralentissements sur la ligne 4",
        ]

        XCTAssertEqual(
            JourneyWarningPresentation.visibleWarnings(from: warnings),
            ["Ralentissements sur la ligne 4"]
        )
    }

    func testKeepsOtherWarnings() {
        let warnings = ["Accès PMR indisponible à Châtelet"]

        XCTAssertEqual(
            JourneyWarningPresentation.visibleWarnings(from: warnings),
            warnings
        )
    }
}
