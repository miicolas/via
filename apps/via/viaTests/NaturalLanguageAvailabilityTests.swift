@testable import Via
import XCTest

final class NaturalLanguageAvailabilityTests: XCTestCase {
    func testAvailableModelExposesNaturalLanguageSearch() {
        XCTAssertEqual(NaturalLanguageAvailability.available.access, .active)
    }

    func testTemporarilyUnavailableModelExplainsHowToRecover() {
        XCTAssertEqual(
            NaturalLanguageAvailability.unavailable(.appleIntelligenceDisabled).access,
            .explanation(.enableAppleIntelligence),
        )
        XCTAssertEqual(
            NaturalLanguageAvailability.unavailable(.modelNotReady).access,
            .explanation(.modelNotReady),
        )
    }

    func testIneligibleDeviceAndUnsupportedLanguageHideNaturalSearch() {
        XCTAssertEqual(
            NaturalLanguageAvailability.unavailable(.deviceNotEligible).access,
            .hidden,
        )
        XCTAssertEqual(
            NaturalLanguageAvailability.unavailable(.unsupportedLanguage).access,
            .hidden,
        )
    }
}
