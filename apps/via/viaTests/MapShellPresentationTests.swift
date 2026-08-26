import SwiftUI
@testable import Via
import XCTest

@MainActor
final class MapShellPresentationTests: XCTestCase {
    func testSearchTransitionUsesJourneySurfaceDetent() {
        XCTAssertEqual(
            MapShellPresentation.detentAfterTabChange(
                from: .stations,
                to: .search,
                isLargeScreen: false,
                hasJourneySurface: true
            ),
            .fraction(0.45)
        )
        XCTAssertEqual(
            MapShellPresentation.detentAfterTabChange(
                from: .stations,
                to: .search,
                isLargeScreen: false,
                hasJourneySurface: false
            ),
            .large
        )
    }

    func testNaturalPanelTransitionIsDirectional() {
        XCTAssertEqual(
            MapShellPresentation.naturalPanelTransition(wasVisible: false, isVisible: true),
            .present
        )
        XCTAssertEqual(
            MapShellPresentation.naturalPanelTransition(wasVisible: true, isVisible: false),
            .dismiss
        )
        XCTAssertNil(MapShellPresentation.naturalPanelTransition(wasVisible: true, isVisible: true))
    }
}
