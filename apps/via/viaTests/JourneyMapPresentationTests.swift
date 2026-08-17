import MapKit
import XCTest
@testable import Via

final class JourneyMapPresentationTests: XCTestCase {
    func testCameraRectContainsOriginDestinationAndRouteGeometry() {
        let journey = JourneyResult.mapPreview.journeys[0]
        let request = JourneyRequest(
            origin: journey.sections[0].from.coordinate,
            destination: .address(
                id: "destination",
                name: "La Défense",
                context: nil,
                coordinate: journey.sections.last!.to.coordinate
            )
        )
        let presentation = JourneyMapPresentation(request: request, journey: journey)

        XCTAssertTrue(presentation.cameraRect.contains(mapPoint(request.origin)))
        XCTAssertTrue(presentation.cameraRect.contains(mapPoint(request.destination.coordinate)))
        for coordinate in journey.sections.flatMap(\.geometry) {
            XCTAssertTrue(presentation.cameraRect.contains(mapPoint(coordinate)))
        }
    }

    func testEndpointOnlyPresentationStillProducesVisibleCameraRect() {
        let request = JourneyRequest(
            origin: GeoCoordinate(latitude: 48.8566, longitude: 2.3522),
            destination: .address(
                id: "same-place",
                name: "Paris",
                context: nil,
                coordinate: GeoCoordinate(latitude: 48.8566, longitude: 2.3522)
            )
        )

        let rect = JourneyMapPresentation(request: request, journey: nil).cameraRect

        XCTAssertGreaterThan(rect.width, 0)
        XCTAssertGreaterThan(rect.height, 0)
        XCTAssertTrue(rect.contains(mapPoint(request.origin)))
    }

    func testDrawableSectionsIgnoreEmptyAndSinglePointGeometry() {
        let journey = JourneyResult.mapPreview.journeys[0]
        let request = JourneyRequest(
            origin: journey.sections[0].from.coordinate,
            destination: .address(
                id: "destination",
                name: "La Défense",
                context: nil,
                coordinate: journey.sections.last!.to.coordinate
            )
        )

        let sections = JourneyMapPresentation(
            request: request,
            journey: journey
        ).drawableSections

        XCTAssertFalse(sections.isEmpty)
        XCTAssertTrue(sections.allSatisfy { $0.geometry.count >= 2 })
        XCTAssertFalse(sections.contains { $0.kind == .transfer })
    }

    func testInvalidGeometryDoesNotAffectCameraFraming() {
        let base = JourneyResult.mapPreview.journeys[0]
        let invalidCoordinate = GeoCoordinate(latitude: 40.7128, longitude: -74.0060)
        let invalidSection = JourneySection(
            id: "invalid-single-point",
            kind: .walk,
            durationSeconds: 60,
            from: base.sections[0].from,
            to: base.sections[0].to,
            departureAt: nil,
            arrivalAt: nil,
            geometry: [invalidCoordinate],
            route: nil,
            direction: nil,
            platform: nil,
            stops: []
        )
        let journey = Journey(
            id: base.id,
            qualifier: base.qualifier,
            durationSeconds: base.durationSeconds,
            walkingDurationSeconds: base.walkingDurationSeconds,
            transferCount: base.transferCount,
            departureAt: base.departureAt,
            arrivalAt: base.arrivalAt,
            status: base.status,
            warnings: base.warnings,
            sections: base.sections + [invalidSection]
        )
        let request = JourneyRequest(
            origin: base.sections[0].from.coordinate,
            destination: .address(
                id: "destination",
                name: "La Défense",
                context: nil,
                coordinate: base.sections.last!.to.coordinate
            )
        )

        let presentation = JourneyMapPresentation(request: request, journey: journey)

        XCTAssertFalse(presentation.cameraRect.contains(mapPoint(invalidCoordinate)))
        XCTAssertFalse(presentation.drawableSections.contains { $0.id == invalidSection.id })
    }

    private func mapPoint(_ coordinate: GeoCoordinate) -> MKMapPoint {
        MKMapPoint(CLLocationCoordinate2D(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        ))
    }
}
