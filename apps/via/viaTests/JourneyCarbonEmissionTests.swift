import XCTest
@testable import Via

final class JourneyCarbonEmissionTests: XCTestCase {
    func testUsesThePublishedModeFactors() {
        XCTAssertEqual(JourneyCarbonEmission.gramsPerPassengerKilometer(for: .metro), 3.8)
        XCTAssertEqual(JourneyCarbonEmission.gramsPerPassengerKilometer(for: .rer), 5.5)
        XCTAssertEqual(JourneyCarbonEmission.gramsPerPassengerKilometer(for: .transilien), 6.6)
        XCTAssertEqual(JourneyCarbonEmission.gramsPerPassengerKilometer(for: .tram), 3.2)
        XCTAssertEqual(JourneyCarbonEmission.gramsPerPassengerKilometer(for: .bus), 92.0)
    }

    func testFormatsTheHeaderValueInFrench() {
        XCTAssertEqual(JourneyFormatting.carbonEmission(grams: 3.8), "3,8 g CO₂e")
        XCTAssertEqual(JourneyFormatting.carbonEmission(grams: 15.2), "15 g CO₂e")
        XCTAssertEqual(JourneyFormatting.carbonEmission(grams: 1_250), "1,3 kg CO₂e")
    }

    func testEstimatesTransitEmissionFromPathDistance() throws {
        let origin = JourneyPlace(
            name: "Départ",
            coordinate: GeoCoordinate(latitude: 48.8566, longitude: 2.3522)
        )
        let destination = JourneyPlace(
            name: "Arrivée",
            coordinate: GeoCoordinate(latitude: 48.8666, longitude: 2.3522)
        )
        let section = JourneySection(
            id: "metro",
            kind: .transit,
            durationSeconds: 600,
            from: origin,
            to: destination,
            departureAt: nil,
            arrivalAt: nil,
            geometry: [origin.coordinate, destination.coordinate],
            route: JourneyRoute(
                id: RouteID(rawValue: "C01371"),
                shortName: "1",
                longName: "Métro 1",
                mode: .metro,
                colorHex: "FFCD00",
                textColorHex: "000000"
            ),
            direction: nil,
            platform: nil,
            stops: []
        )
        let journey = makeJourney(sections: [section])

        let emission = journey.carbonEmission
        let distance = origin.coordinate.metersAway(from: destination.coordinate)

        XCTAssertEqual(emission.transitDistanceMeters, distance, accuracy: 0.001)
        XCTAssertEqual(emission.grams, distance / 1_000 * 3.8, accuracy: 0.001)
    }

    func testWalkingAndBikeJourneysHaveZeroTransitEmission() {
        let place = JourneyPlace(
            name: "Même lieu",
            coordinate: GeoCoordinate(latitude: 48.8566, longitude: 2.3522)
        )
        let walking = JourneySection(
            id: "walk",
            kind: .walk,
            durationSeconds: 300,
            from: place,
            to: place,
            departureAt: nil,
            arrivalAt: nil,
            geometry: [],
            route: nil,
            direction: nil,
            platform: nil,
            stops: []
        )
        let journey = makeJourney(sections: [walking])

        XCTAssertEqual(journey.carbonEmission.grams, 0)
        XCTAssertEqual(journey.carbonEmission.transitDistanceMeters, 0)
    }

    private func makeJourney(sections: [JourneySection]) -> Journey {
        Journey(
            id: JourneyID(rawValue: "test:carbon"),
            qualifier: .recommended,
            durationSeconds: sections.reduce(0) { $0 + $1.durationSeconds },
            walkingDurationSeconds: sections
                .filter { $0.kind == .walk }
                .reduce(0) { $0 + $1.durationSeconds },
            transferCount: 0,
            departureAt: Date(timeIntervalSince1970: 1_700_000_000),
            arrivalAt: Date(timeIntervalSince1970: 1_700_000_600),
            status: .normal,
            warnings: [],
            sections: sections
        )
    }
}
