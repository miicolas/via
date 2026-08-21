@testable import Via
import XCTest

final class ExplicitRouteSyntaxTests: XCTestCase {
    func testBareOriginBeforeVersIsExplicit() {
        XCTAssertEqual(
            ExplicitRouteSyntax.originQuery(in: "gare du nord vers orly sans rer"),
            "gare du nord",
        )
    }

    func testDepuisPrefixIsNotPartOfOrigin() {
        XCTAssertEqual(
            ExplicitRouteSyntax.originQuery(in: "Depuis Gare du Nord vers Orly"),
            "Gare du Nord",
        )
    }

    func testTravelVerbBeforeVersIsNotAnOrigin() {
        XCTAssertNil(ExplicitRouteSyntax.originQuery(in: "je veux aller vers Orly"))
    }

    func testPhraseWithoutDirectionalSeparatorHasNoExplicitOrigin() {
        XCTAssertNil(ExplicitRouteSyntax.originQuery(in: "aller à Orly sans RER"))
    }

    func testDetectedOriginReplacesOnlyAnImplicitCurrentLocation() throws {
        let query = try XCTUnwrap(
            ExplicitRouteSyntax.originQuery(in: "gare du nord vers orly sans rer"),
        )
        let corrected = makeIntent(
            origin: .currentLocation,
            originWasExplicit: false,
        ).replacingImplicitOrigin(with: query)

        XCTAssertEqual(corrected.origin, .place(query: "gare du nord"))
        XCTAssertTrue(corrected.originWasExplicit)
    }

    func testDetectedOriginDoesNotOverwriteAnExplicitModelOrigin() {
        let intent = makeIntent(
            origin: .place(query: "Châtelet"),
            originWasExplicit: true,
        )

        XCTAssertEqual(
            intent.replacingImplicitOrigin(with: "gare du nord"),
            intent,
        )
    }

    private func makeIntent(
        origin: RouteOriginIntent,
        originWasExplicit: Bool,
    ) -> RouteIntent {
        RouteIntent(
            scope: .journey,
            origin: origin,
            destinationQuery: "orly",
            requestedAt: nil,
            datetimeRepresents: .departure,
            requiredModes: [],
            excludedModes: [.rer],
            preferredModes: [],
            dateWasExplicit: false,
            timeWasExplicit: false,
            originWasExplicit: originWasExplicit,
        )
    }
}
