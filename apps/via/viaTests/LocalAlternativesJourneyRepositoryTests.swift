import XCTest
@testable import Via

final class LocalAlternativesJourneyRepositoryTests: XCTestCase {
    func testMergesLocalWalkingAndCyclingRoutesWithTransit() async throws {
        let transit = try XCTUnwrap(JourneyResult.mapPreview.journeys.first)
        let serverWalking = directJourney(kind: .walk, id: "server-walking", duration: 1_500)
        let localWalking = directJourney(kind: .walk, id: "local-walking", duration: 900)
        let localCycling = directJourney(kind: .bike, id: "local-cycling", duration: 600)
        let base = JourneyResult(
            status: .ready,
            source: .realtime,
            generatedAt: .now,
            journeys: [transit, serverWalking]
        )
        let repository = LocalAlternativesJourneyRepository(
            base: FixedJourneyRepository(result: base),
            direct: FixedDirectJourneyRouter(routes: [localWalking, localCycling])
        )

        let result = try await repository.plan(makeRequest())

        XCTAssertEqual(
            result.journeys.map(\.id.rawValue),
            [transit.id.rawValue, localWalking.id.rawValue, localCycling.id.rawValue]
        )
        XCTAssertEqual(result.journeys[1].durationSeconds, 900)
        XCTAssertEqual(result.journeys[2].qualifier, .bike)
    }

    func testOffersLocalRouteWithoutClaimingAPlanWhenServerIsUnavailable() async throws {
        let localWalking = directJourney(kind: .walk, id: "local-walking", duration: 900)
        let repository = LocalAlternativesJourneyRepository(
            base: FailingJourneyRepository(),
            direct: FixedDirectJourneyRouter(routes: [localWalking])
        )

        let result = try await repository.plan(makeRequest())

        XCTAssertEqual(result.status, .unavailable)
        XCTAssertEqual(result.reason, .transitUnavailable)
        XCTAssertEqual(result.source, .theoretical)
        XCTAssertEqual(result.journeys.map(\.id.rawValue), ["local-walking"])
    }

    func testLocalRoutesDoNotTurnAnEmptyPlanIntoAResult() async throws {
        let localWalking = directJourney(kind: .walk, id: "local-walking", duration: 900)
        let base = JourneyResult(
            status: .noRoute,
            source: .realtime,
            generatedAt: .now,
            journeys: []
        )
        let repository = LocalAlternativesJourneyRepository(
            base: FixedJourneyRepository(result: base),
            direct: FixedDirectJourneyRouter(routes: [localWalking])
        )

        let result = try await repository.plan(makeRequest())

        XCTAssertEqual(result.status, .noRoute)
        XCTAssertEqual(result.journeys.map(\.id.rawValue), ["local-walking"])
    }

    func testLocalRoutesKeepTheReasonOfAFilteredPlan() async throws {
        let localCycling = directJourney(kind: .bike, id: "local-cycling", duration: 600)
        let base = JourneyResult(
            status: .noRoute,
            source: .realtime,
            generatedAt: .now,
            journeys: [],
            reason: .noAccessibleRoute
        )
        let repository = LocalAlternativesJourneyRepository(
            base: FixedJourneyRepository(result: base),
            direct: FixedDirectJourneyRouter(routes: [localCycling])
        )

        let result = try await repository.plan(makeRequest())

        XCTAssertEqual(result.status, .noRoute)
        XCTAssertEqual(result.reason, .noAccessibleRoute)
    }

    private func makeRequest() -> JourneyRequest {
        JourneyRequest(
            origin: GeoCoordinate(latitude: 48.8566, longitude: 2.3522),
            destination: .station(
                id: StationID(rawValue: "destination"),
                name: "Destination",
                coordinate: GeoCoordinate(latitude: 48.8584, longitude: 2.3470)
            )
        )
    }

    private func directJourney(
        kind: JourneySection.Kind,
        id: String,
        duration: Int
    ) -> Journey {
        let origin = JourneyPlace(
            name: "Départ",
            coordinate: GeoCoordinate(latitude: 48.8566, longitude: 2.3522)
        )
        let destination = JourneyPlace(
            name: "Destination",
            coordinate: GeoCoordinate(latitude: 48.8584, longitude: 2.3470)
        )
        let departure = Date(timeIntervalSince1970: 1_000)
        let arrival = departure.addingTimeInterval(TimeInterval(duration))
        return Journey(
            id: JourneyID(rawValue: id),
            qualifier: kind == .walk ? .walking : .bike,
            durationSeconds: duration,
            walkingDurationSeconds: kind == .walk ? duration : 0,
            transferCount: 0,
            departureAt: departure,
            arrivalAt: arrival,
            status: .theoretical,
            warnings: [],
            sections: [
                JourneySection(
                    id: "\(id):section",
                    timingSource: .theoretical,
                    kind: kind,
                    durationSeconds: duration,
                    from: origin,
                    to: destination,
                    departureAt: departure,
                    arrivalAt: arrival,
                    geometry: [origin.coordinate, destination.coordinate],
                    route: nil,
                    direction: nil,
                    platform: nil,
                    stops: []
                )
            ]
        )
    }
}

private struct FixedJourneyRepository: JourneyRepository, Sendable {
    let result: JourneyResult

    func plan(_ request: JourneyRequest) async throws -> JourneyResult {
        result
    }
}

private struct FailingJourneyRepository: JourneyRepository, Sendable {
    func plan(_ request: JourneyRequest) async throws -> JourneyResult {
        throw TestPlanningError()
    }
}

private struct FixedDirectJourneyRouter: DirectJourneyRouter, Sendable {
    let routes: [Journey]

    func routes(for request: JourneyRequest) async -> [Journey] {
        routes
    }
}

private struct TestPlanningError: Error, Sendable {}
