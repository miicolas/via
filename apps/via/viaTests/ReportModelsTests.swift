import XCTest
@testable import Via

final class ReportModelsTests: XCTestCase {
    func testStationCategoriesExposeTheExpectedGroupsAndOrder() {
        XCTAssertEqual(ReportCategory.allCases.count, 12)
        XCTAssertEqual(
            ReportCategoryGroup.safetyAndCrowding.categories,
            [.pickpocket, .crowding]
        )
        XCTAssertEqual(
            ReportCategoryGroup.accessibilityAndEquipment.categories,
            [
                .restroomsClosed,
                .ticketMachinesUnavailable,
                .elevatorsUnavailable,
                .escalatorUnavailable,
                .validatorsUnavailable,
            ]
        )
        XCTAssertEqual(
            ReportCategoryGroup.accessAndService.categories,
            [
                .entranceOrExitClosed,
                .stopRelocated,
                .stopNotServed,
                .passengerInformationUnavailable,
                .passageObstructed,
            ]
        )
    }

    func testCrowdingLevelsExposeFourMeaningfulChoices() {
        XCTAssertEqual(CrowdingLevel.allCases, [.low, .moderate, .high, .saturated])
        XCTAssertEqual(CrowdingLevel.allCases.map(\.title), ["Faible", "Modérée", "Forte", "Saturée"])
        XCTAssertTrue(CrowdingLevel.allCases.allSatisfy { !$0.explanation.isEmpty })
    }

    func testReportValueDistinguishesOccurrenceFromCrowding() {
        XCTAssertNotEqual(ReportValue.occurrence, .crowding(.high))
        XCTAssertEqual(ReportValue.crowding(.saturated), .crowding(.saturated))
    }

    func testReportContextRoundsTheReportedCoordinate() {
        let station = ReportStation(
            id: StationID(rawValue: "station"),
            name: "Station",
            coordinate: GeoCoordinate(latitude: 48.123_456, longitude: 2.987_654)
        )

        let context = ReportContext(
            coordinate: GeoCoordinate(latitude: 48.123_456, longitude: 2.987_654),
            station: station
        )

        XCTAssertEqual(context.coordinate.latitude, 48.1235, accuracy: 0.000_000_1)
        XCTAssertEqual(context.coordinate.longitude, 2.9877, accuracy: 0.000_000_1)
        XCTAssertNil(context.lineID)
        XCTAssertNil(context.journeyID)
        XCTAssertNil(context.vehicleID)
    }

    func testReportContextCarriesOptionalJourneyFields() {
        let station = ReportStation(
            id: StationID(rawValue: "station"),
            name: "Station",
            coordinate: GeoCoordinate(latitude: 48.8, longitude: 2.3)
        )
        let context = ReportContext(
            coordinate: station.coordinate,
            station: station,
            lineID: RouteID(rawValue: "line"),
            journeyID: JourneyID(rawValue: "journey"),
            vehicleID: "vehicle"
        )

        XCTAssertEqual(context.lineID, RouteID(rawValue: "line"))
        XCTAssertEqual(context.journeyID, JourneyID(rawValue: "journey"))
        XCTAssertEqual(context.vehicleID, "vehicle")
    }

    func testInMemoryRepositoryKeepsSubmissionsForTheCurrentSession() async throws {
        let repository = InMemoryReportRepository()
        let submission = ReportSubmission(
            category: .pickpocket,
            value: .occurrence,
            context: sampleContext
        )

        try await repository.submit(submission)

        let stored = await repository.submissions()
        XCTAssertEqual(stored, [submission])
    }

    func testV1ActiveJourneyProviderReturnsNoJourney() async {
        let journey = await NoActiveJourneyProvider().activeJourney()
        XCTAssertNil(journey)
    }

    private var sampleContext: ReportContext {
        let station = ReportStation(
            id: StationID(rawValue: "station"),
            name: "Station",
            coordinate: GeoCoordinate(latitude: 48.8, longitude: 2.3)
        )
        return ReportContext(coordinate: station.coordinate, station: station)
    }
}
