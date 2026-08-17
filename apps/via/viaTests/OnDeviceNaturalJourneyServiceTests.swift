import XCTest
@testable import Via

final class OnDeviceNaturalJourneyServiceTests: XCTestCase {
    private let now = ISO8601.parse("2026-08-17T09:00:00+02:00")!

    func testSubmitProducesOnDeviceReadyResultAndPlansVerifiedPlaces() async throws {
        let destination = address("nation", "Nation")
        let recorder = OnDeviceJourneyRecorder(results: [.mapPreview])
        let parser = InMemoryNaturalIntentParser(
            intent: intent(destination: "Nation", requestedAt: now, preferredModes: [.bus]),
            answer: "Voici le meilleur trajet vérifié."
        )
        let service = makeService(parser: parser, results: [destination], journeys: recorder)
        let coordinate = GeoCoordinate(latitude: 48.85, longitude: 2.35)

        let result = try await service.submit(.submit(
            query: "Nation plutôt en bus",
            currentLocation: coordinate
        ))

        guard case .ready(_, .onDevice, _, let interpretation, _) = result else {
            return XCTFail("Expected an on-device ready result")
        }
        XCTAssertEqual(interpretation.destinationResult, destination)
        let requests = await recorder.requests
        XCTAssertEqual(requests.count, 1)
        XCTAssertEqual(requests[0].origin, coordinate)
        XCTAssertEqual(requests[0].limit, 4)
        XCTAssertEqual(requests[0].preferredModes, [.bus])
    }

    func testAmbiguousOriginReturnsCandidateClarification() async throws {
        let first = station("gare-1", "Gare du Nord")
        let second = station("gare-2", "Gare de Lyon")
        let destination = address("nation", "Nation")
        let parser = InMemoryNaturalIntentParser(intent: RouteIntent(
            scope: .journey,
            origin: .place(query: "gare"),
            destinationQuery: "Nation",
            requestedAt: now,
            datetimeRepresents: .departure,
            requiredModes: [], excludedModes: [], preferredModes: []
        ))
        let service = makeService(parser: parser) { query in
            query == "gare" ? [first, second] : [destination]
        }

        let result = try await service.submit(.submit(query: "de la gare à Nation", currentLocation: nil))

        guard case .needsClarification(_, let fields) = result else {
            return XCTFail("Expected clarification")
        }
        XCTAssertEqual(fields.first?.target, .origin)
        XCTAssertEqual(fields.first?.candidates, [first, second])
    }

    func testMissingTimeReturnsTimeClarification() async throws {
        let destination = address("nation", "Nation")
        let parser = InMemoryNaturalIntentParser(intent: intent(
            destination: "Nation",
            requestedAt: nil
        ))
        let service = makeService(parser: parser, results: [destination])

        let result = try await service.submit(.submit(
            query: "Je veux aller à Nation",
            currentLocation: .init(latitude: 48.85, longitude: 2.35)
        ))

        guard case .needsClarification(_, let fields) = result else {
            return XCTFail("Expected clarification")
        }
        XCTAssertEqual(fields.map(\.target), [.time])
        XCTAssertEqual(fields.first?.question, "Pour quand ?")
    }

    func testResolveVerifiesCandidateWithoutCallingParserAndCompletesJourney() async throws {
        let origin = station("chatelet", "Châtelet")
        let destination = address("nation", "Nation")
        let parser = InMemoryNaturalIntentParser(parsingError: .modelFailed)
        let draft = NaturalJourneyDraft(
            intent: RouteIntent(
                scope: .journey,
                origin: .place(query: "Châtelet"),
                destinationQuery: "Nation",
                requestedAt: now,
                datetimeRepresents: .departure,
                requiredModes: [], excludedModes: [], preferredModes: []
            ),
            origin: nil,
            destination: destination
        )
        let service = makeService(parser: parser) { query in
            query == "Châtelet" ? [origin] : [destination]
        }

        let result = try await service.submit(.resolve(
            draft: draft,
            currentLocation: nil,
            origin: origin,
            destination: nil,
            datetimeRepresents: nil
        ))

        guard case .ready(_, .deterministic, _, let interpretation, _) = result else {
            return XCTFail("Expected a deterministic ready result")
        }
        XCTAssertEqual(interpretation.originLabel, "Châtelet")
    }

    func testUnsupportedIntentReturnsFixedScopeMessage() async throws {
        let parser = InMemoryNaturalIntentParser(intent: RouteIntent(
            scope: .unsupported,
            origin: .currentLocation,
            destinationQuery: nil,
            requestedAt: now,
            datetimeRepresents: .departure,
            requiredModes: [], excludedModes: [], preferredModes: []
        ))
        let service = makeService(parser: parser)

        let result = try await service.submit(.submit(query: "Quel temps fera-t-il ?", currentLocation: nil))

        guard case .unsupported(let message, let examples) = result else {
            return XCTFail("Expected unsupported")
        }
        XCTAssertEqual(message, "Via peut t’aider à préparer un trajet en Île-de-France")
        XCTAssertEqual(examples.count, 2)
    }

    func testMissingCurrentLocationAsksForOrigin() async throws {
        let destination = address("nation", "Nation")
        let parser = InMemoryNaturalIntentParser(intent: intent(
            destination: "Nation",
            requestedAt: now
        ))
        let service = makeService(parser: parser, results: [destination])

        let result = try await service.submit(.submit(query: "Nation à 10 h", currentLocation: nil))

        guard case .needsClarification(_, let fields) = result else {
            return XCTFail("Expected clarification")
        }
        XCTAssertEqual(fields.first?.target, .origin)
        XCTAssertEqual(fields.first?.question, "D’où pars-tu ?")
    }

    private func makeService(
        parser: any NaturalIntentParsing,
        results: [SearchResult] = [],
        journeys: any JourneyRepository = InMemoryJourneyRepository(result: .mapPreview)
    ) -> OnDeviceNaturalJourneyService {
        makeService(parser: parser, journeys: journeys) { _ in results }
    }

    private func makeService(
        parser: any NaturalIntentParsing,
        journeys: any JourneyRepository = InMemoryJourneyRepository(result: .mapPreview),
        results: @escaping @Sendable (String) -> [SearchResult]
    ) -> OnDeviceNaturalJourneyService {
        let fixedNow = now
        return OnDeviceNaturalJourneyService(
            parser: parser,
            places: OnDevicePlaceResolver { query, _ in
                SearchResponse(results: results(query), addressSource: .ok)
            },
            journeys: journeys,
            now: { fixedNow }
        )
    }

    private func intent(
        destination: String,
        requestedAt: Date?,
        preferredModes: Set<TransitMode> = []
    ) -> RouteIntent {
        RouteIntent(
            scope: .journey,
            origin: .currentLocation,
            destinationQuery: destination,
            requestedAt: requestedAt,
            datetimeRepresents: .departure,
            requiredModes: [],
            excludedModes: [],
            preferredModes: preferredModes
        )
    }

    private func station(_ id: String, _ name: String) -> SearchResult {
        .station(.init(
            id: .init(rawValue: id),
            name: name,
            coordinate: .init(latitude: 48.85, longitude: 2.35),
            routes: [],
            distanceMeters: nil
        ))
    }

    private func address(_ id: String, _ name: String) -> SearchResult {
        .address(.init(
            id: id,
            name: name,
            context: "Paris",
            coordinate: .init(latitude: 48.86, longitude: 2.36),
            distanceMeters: nil
        ))
    }
}

private actor OnDeviceJourneyRecorder: JourneyRepository {
    private let results: [JourneyResult]
    private(set) var requests: [JourneyRequest] = []

    init(results: [JourneyResult]) {
        self.results = results
    }

    func plan(_ request: JourneyRequest) async throws -> JourneyResult {
        requests.append(request)
        return results[min(requests.count - 1, results.count - 1)]
    }
}
