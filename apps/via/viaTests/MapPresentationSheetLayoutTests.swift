import SwiftUI
import XCTest
@testable import Via

final class MapPresentationSheetLayoutTests: XCTestCase {
    func testWidePresentationKeepsCollapsedDetent() {
        let detent = MapPresentationSheetLayout.presentedDetent(
            MapPresentationState.collapsedDetent,
            isLargeScreen: true
        )

        XCTAssertEqual(detent, MapPresentationState.collapsedDetent)
    }

    func testWidePresentationNormalizesExpandedDetents() {
        let detent = MapPresentationSheetLayout.presentedDetent(
            .large,
            isLargeScreen: true
        )

        XCTAssertEqual(detent, MapPresentationState.expandedDetent)
    }

    func testReturningToCompactUsesSearchDetent() {
        let detent = MapPresentationSheetLayout.transitionedDetent(
            MapPresentationState.expandedDetent,
            isLargeScreen: false
        )

        XCTAssertEqual(detent, MapPresentationState.searchDetent)
    }

    func testJourneyCompactLayoutSupportsMessageHeight() {
        XCTAssertEqual(
            MapPresentationSheetLayout.journeyCompactDetents,
            [
                MapPresentationState.collapsedDetent,
                MapPresentationSheetLayout.naturalMessageDetent,
                MapPresentationState.searchDetent,
                .large,
            ]
        )
    }

    func testNaturalJourneyErrorUsesContentSizedDetent() {
        let detent = MapPresentationSheetLayout.journeyDetent(
            for: .loaded(.unavailable(message: "Indisponible")),
            isLargeScreen: false
        )

        XCTAssertEqual(detent, MapPresentationSheetLayout.naturalMessageDetent)
    }

    func testNaturalJourneyLoadingUsesSearchDetent() {
        let detent = MapPresentationSheetLayout.journeyDetent(
            for: .loading(previous: nil),
            isLargeScreen: false
        )

        XCTAssertEqual(detent, MapPresentationState.searchDetent)
    }
}
