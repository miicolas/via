import MapKit
import XCTest
@testable import Via

final class JourneyMapPresentationTests: XCTestCase {
    func testRecommendedExitReplacesItsAlightingMarker() throws {
        let journey = makeJourney(
            exit: JourneyExit(
                id: "exit:6",
                name: "boulevard Henri IV",
                number: 6,
                coordinate: GeoCoordinate(latitude: 48.95, longitude: 2.5),
                walkingMeters: 50
            )
        )

        let presentation = JourneyMapPresentation(journey: journey)
        let exit = try XCTUnwrap(presentation.exits.first)

        XCTAssertEqual(exit.number, 6)
        XCTAssertEqual(exit.name, "boulevard Henri IV")
        XCTAssertEqual(exit.walkingMeters, 50)
        XCTAssertFalse(
            presentation.stops.contains {
                $0.sectionIndex == exit.sectionIndex && $0.kind == .alight
            }
        )
        XCTAssertEqual(
            exit.accessibilityLabel,
            "Sortie recommandée, Sortie numéro 6, boulevard Henri IV, à environ 50 m de votre destination"
        )
    }

    func testExitParticipatesInWholeJourneyAndSectionFraming() throws {
        let exitCoordinate = GeoCoordinate(latitude: 48.95, longitude: 2.5)
        let journey = makeJourney(
            exit: JourneyExit(
                id: "exit:3",
                name: "Parvis",
                number: 3,
                coordinate: exitCoordinate,
                walkingMeters: 180
            )
        )
        let presentation = JourneyMapPresentation(journey: journey)
        let exit = try XCTUnwrap(presentation.exits.first)
        let point = MKMapPoint(exitCoordinate.clLocationCoordinate)

        let wholeRect = try XCTUnwrap(presentation.mapRect)
        let sectionRect = try XCTUnwrap(
            presentation.mapRect(for: presentation.segments[exit.sectionIndex].id)
        )

        XCTAssertTrue(wholeRect.contains(point))
        XCTAssertTrue(sectionRect.contains(point))
    }

    func testJourneyWithoutRecommendedExitKeepsAlightingMarker() throws {
        let journey = makeJourney(exit: nil)
        let presentation = JourneyMapPresentation(journey: journey)
        let targetSectionIndex = try XCTUnwrap(
            journey.sections.firstIndex { $0.kind == .transit && $0.to.name == "La Défense" }
        )

        XCTAssertTrue(presentation.exits.isEmpty)
        XCTAssertTrue(
            presentation.stops.contains {
                $0.sectionIndex == targetSectionIndex && $0.kind == .alight
            }
        )
    }

    func testUnnumberedExitKeepsACompleteAccessibilityLabel() throws {
        let journey = makeJourney(
            exit: JourneyExit(
                id: "exit:unnumbered",
                name: "place de la Bastille",
                number: nil,
                coordinate: GeoCoordinate(latitude: 48.853, longitude: 2.369),
                walkingMeters: nil
            )
        )

        let exit = try XCTUnwrap(JourneyMapPresentation(journey: journey).exits.first)

        XCTAssertNil(exit.number)
        XCTAssertEqual(
            exit.accessibilityLabel,
            "Sortie recommandée, Sortie place de la Bastille"
        )
    }

    private func makeJourney(exit: JourneyExit?) -> Journey {
        let base = JourneyResult.mapPreview.journeys[0]
        guard let targetIndex = base.sections.firstIndex(where: { $0.exit != nil }) else {
            preconditionFailure("The journey preview must contain a recommended exit")
        }
        let sections = base.sections.enumerated().map { index, section in
            guard index == targetIndex else { return section }
            return JourneySection(
                id: section.id,
                kind: section.kind,
                durationSeconds: section.durationSeconds,
                from: section.from,
                to: section.to,
                departureAt: section.departureAt,
                arrivalAt: section.arrivalAt,
                geometry: section.geometry,
                route: section.route,
                direction: section.direction,
                platform: section.platform,
                stops: section.stops,
                boardingPosition: section.boardingPosition,
                exit: exit
            )
        }

        return Journey(
            id: base.id,
            qualifier: base.qualifier,
            durationSeconds: base.durationSeconds,
            walkingDurationSeconds: base.walkingDurationSeconds,
            transferCount: base.transferCount,
            departureAt: base.departureAt,
            arrivalAt: base.arrivalAt,
            status: base.status,
            warnings: base.warnings,
            accessibility: base.accessibility,
            peak: base.peak,
            sections: sections
        )
    }
}
