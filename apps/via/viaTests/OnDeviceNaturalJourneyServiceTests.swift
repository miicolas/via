@testable import Via
import XCTest

final class OnDeviceNaturalJourneyServiceTests: XCTestCase {
    private let now = ISO8601.parse("2026-08-17T09:00:00+02:00")!

    func testMissingOriginProposesCurrentLocationBeforePlanning() async throws {
        let destination = address("nation", "Nation")
        let parser = InMemoryNaturalIntentParser(intent: RouteIntent(
            scope: .journey,
            origin: .currentLocation,
            destinationQuery: "Nation",
            requestedAt: now,
            datetimeRepresents: .departure,
            requiredModes: [],
            excludedModes: [],
            preferredModes: [],
            originWasExplicit: false,
        ))
        let journeys = OnDeviceJourneyRecorder(results: [.mapPreview])
        let service = makeService(parser: parser, results: [destination], journeys: journeys)

        let result = try await service.submit(.submit(
            query: "Nation demain à 9 h",
            currentLocation: GeoCoordinate(latitude: 48.85, longitude: 2.35),
        ))

        guard case .needsDecision(_, .currentLocation) = result else {
            return XCTFail("Expected an explicit current-location decision")
        }
        let requests = await journeys.requests
        XCTAssertTrue(requests.isEmpty)
    }

    func testConfirmingCurrentLocationContinuesPlanning() async throws {
        let coordinate = GeoCoordinate(latitude: 48.85, longitude: 2.35)
        let destination = address("nation", "Nation")
        let draft = NaturalJourneyDraft(
            intent: RouteIntent(
                scope: .journey,
                origin: .currentLocation,
                destinationQuery: "Nation",
                requestedAt: now,
                datetimeRepresents: .departure,
                requiredModes: [],
                excludedModes: [],
                preferredModes: [],
                originWasExplicit: false,
            ),
            origin: nil,
            destination: destination,
        )
        let journeys = OnDeviceJourneyRecorder(results: [.mapPreview])
        let service = makeService(
            parser: InMemoryNaturalIntentParser(intent: draft.intent),
            results: [destination],
            journeys: journeys,
        )

        let result = try await service.submit(.confirmCurrentLocation(
            draft: draft,
            currentLocation: coordinate,
        ))

        guard case .ready = result else {
            return XCTFail("Expected a ready result")
        }
        let requests = await journeys.requests
        XCTAssertEqual(requests.first?.origin, coordinate)
    }

    func testConflictingModeRequiresAUserDecisionBeforePlanning() async throws {
        let destination = address("nation", "Nation")
        let parser = InMemoryNaturalIntentParser(intent: RouteIntent(
            scope: .journey,
            origin: .currentLocation,
            destinationQuery: "Nation",
            requestedAt: now,
            datetimeRepresents: .departure,
            requiredModes: [.metro],
            excludedModes: [.metro],
            preferredModes: [],
        ))
        let journeys = OnDeviceJourneyRecorder(results: [.mapPreview])
        let service = makeService(parser: parser, results: [destination], journeys: journeys)

        let result = try await service.submit(.submit(
            query: "Nation uniquement en métro, sans métro",
            currentLocation: GeoCoordinate(latitude: 48.85, longitude: 2.35),
        ))

        guard case let .needsDecision(_, .modeConflict(mode, choices)) = result else {
            return XCTFail("Expected a mode conflict decision")
        }
        XCTAssertEqual(mode, .metro)
        XCTAssertEqual(choices, [.required, .excluded])
        let requests = await journeys.requests
        XCTAssertTrue(requests.isEmpty)
    }

    func testResolvingAModeConflictKeepsTheUsersChosenConstraint() async throws {
        let destination = address("nation", "Nation")
        let draft = NaturalJourneyDraft(
            intent: RouteIntent(
                scope: .journey,
                origin: .currentLocation,
                destinationQuery: "Nation",
                requestedAt: now,
                datetimeRepresents: .departure,
                requiredModes: [.metro],
                excludedModes: [.metro],
                preferredModes: [],
            ),
            origin: nil,
            destination: destination,
        )
        let journeys = OnDeviceJourneyRecorder(results: [.mapPreview])
        let service = makeService(
            parser: InMemoryNaturalIntentParser(),
            results: [destination],
            journeys: journeys,
        )

        let result = try await service.submit(.resolveModeConflict(
            draft: draft,
            currentLocation: GeoCoordinate(latitude: 48.85, longitude: 2.35),
            mode: .metro,
            keeping: .required,
        ))

        guard case .ready = result else {
            return XCTFail("Expected a ready result")
        }
        let recordedRequests = await journeys.requests
        let request = try XCTUnwrap(recordedRequests.first)
        XCTAssertEqual(request.requiredModes, [.metro])
        XCTAssertTrue(request.excludedModes.isEmpty)
    }

    func testPreferredAndExcludedModeConflictCanKeepThePreference() async throws {
        let destination = address("nation", "Nation")
        let draft = NaturalJourneyDraft(
            intent: RouteIntent(
                scope: .journey,
                origin: .currentLocation,
                destinationQuery: "Nation",
                requestedAt: now,
                datetimeRepresents: .departure,
                requiredModes: [],
                excludedModes: [.bus],
                preferredModes: [.bus],
            ),
            origin: nil,
            destination: destination,
        )
        let journeys = OnDeviceJourneyRecorder(results: [.mapPreview])
        let service = makeService(
            parser: InMemoryNaturalIntentParser(),
            results: [destination],
            journeys: journeys,
        )

        let decision = try await service.submit(.submit(
            query: "Nation plutôt en bus mais sans bus",
            currentLocation: GeoCoordinate(latitude: 48.85, longitude: 2.35),
        ))
        guard case let .needsDecision(_, .modeConflict(mode, choices)) = decision else {
            return XCTFail("Expected a preferred/excluded conflict")
        }
        XCTAssertEqual(mode, .bus)
        XCTAssertEqual(choices, [.preferred, .excluded])

        let result = try await service.submit(.resolveModeConflict(
            draft: draft,
            currentLocation: GeoCoordinate(latitude: 48.85, longitude: 2.35),
            mode: .bus,
            keeping: .preferred,
        ))

        guard case .ready = result else {
            return XCTFail("Expected a ready result")
        }
        let recordedRequests = await journeys.requests
        let request = recordedRequests.first
        XCTAssertEqual(request?.preferredModes, [.bus])
        XCTAssertTrue(request?.excludedModes.isEmpty == true)
    }

    func testUnsupportedJourneyConstraintMustBeAcknowledgedBeforePlanning() async throws {
        let destination = address("nation", "Nation")
        let parser = InMemoryNaturalIntentParser(intent: RouteIntent(
            scope: .journey,
            origin: .currentLocation,
            destinationQuery: "Nation",
            requestedAt: now,
            datetimeRepresents: .departure,
            requiredModes: [],
            excludedModes: [],
            preferredModes: [],
            unsupportedConstraints: ["moins de dix minutes de marche"],
        ))
        let journeys = OnDeviceJourneyRecorder(results: [.mapPreview])
        let service = makeService(parser: parser, results: [destination], journeys: journeys)

        let result = try await service.submit(.submit(
            query: "Nation avec moins de dix minutes de marche",
            currentLocation: GeoCoordinate(latitude: 48.85, longitude: 2.35),
        ))

        guard case let .needsDecision(_, .unsupportedConstraints(constraints)) = result else {
            return XCTFail("Expected unsupported constraints decision")
        }
        XCTAssertEqual(constraints, ["moins de dix minutes de marche"])
        let requests = await journeys.requests
        XCTAssertTrue(requests.isEmpty)
    }

    func testUserCanContinueWithoutAnUnsupportedConstraint() async throws {
        let destination = address("nation", "Nation")
        let draft = NaturalJourneyDraft(
            intent: RouteIntent(
                scope: .journey,
                origin: .currentLocation,
                destinationQuery: "Nation",
                requestedAt: now,
                datetimeRepresents: .departure,
                requiredModes: [],
                excludedModes: [],
                preferredModes: [],
                unsupportedConstraints: ["accessible en fauteuil"],
            ),
            origin: nil,
            destination: destination,
        )
        let journeys = OnDeviceJourneyRecorder(results: [.mapPreview])
        let service = makeService(
            parser: InMemoryNaturalIntentParser(),
            results: [destination],
            journeys: journeys,
        )

        let result = try await service.submit(.continueWithoutUnsupportedConstraints(
            draft: draft,
            currentLocation: GeoCoordinate(latitude: 48.85, longitude: 2.35),
        ))

        guard case .ready = result else {
            return XCTFail("Expected a ready result")
        }
        let requests = await journeys.requests
        XCTAssertEqual(requests.count, 1)
    }

    func testPastTimeWithoutAnExplicitDateMovesToTheNextDay() async throws {
        let requestedAt = ISO8601.parse("2026-08-17T08:00:00+02:00")!
        let expected = ISO8601.parse("2026-08-18T08:00:00+02:00")!
        let destination = address("nation", "Nation")
        let parser = InMemoryNaturalIntentParser(intent: RouteIntent(
            scope: .journey,
            origin: .currentLocation,
            destinationQuery: "Nation",
            requestedAt: requestedAt,
            datetimeRepresents: .departure,
            requiredModes: [],
            excludedModes: [],
            preferredModes: [],
            dateWasExplicit: false,
            timeWasExplicit: true,
        ))
        let journeys = OnDeviceJourneyRecorder(results: [.mapPreview])
        let service = makeService(parser: parser, results: [destination], journeys: journeys)

        _ = try await service.submit(.submit(
            query: "Nation après 8 h",
            currentLocation: GeoCoordinate(latitude: 48.85, longitude: 2.35),
        ))

        let requests = await journeys.requests
        XCTAssertEqual(requests.first?.requestedAt, expected)
    }

    func testPastTimeWithAnExplicitDateRequiresCorrection() async throws {
        let requestedAt = ISO8601.parse("2026-08-17T08:00:00+02:00")!
        let destination = address("nation", "Nation")
        let parser = InMemoryNaturalIntentParser(intent: RouteIntent(
            scope: .journey,
            origin: .currentLocation,
            destinationQuery: "Nation",
            requestedAt: requestedAt,
            datetimeRepresents: .departure,
            requiredModes: [],
            excludedModes: [],
            preferredModes: [],
            dateWasExplicit: true,
            timeWasExplicit: true,
        ))
        let journeys = OnDeviceJourneyRecorder(results: [.mapPreview])
        let service = makeService(parser: parser, results: [destination], journeys: journeys)

        let result = try await service.submit(.submit(
            query: "Aujourd’hui vers Nation après 8 h",
            currentLocation: GeoCoordinate(latitude: 48.85, longitude: 2.35),
        ))

        guard case let .needsDecision(_, .pastDate(value)) = result else {
            return XCTFail("Expected a past date decision")
        }
        XCTAssertEqual(value, requestedAt)
        let requests = await journeys.requests
        XCTAssertTrue(requests.isEmpty)
    }

    func testDepartureAndArrivalTimesRequireAUserDecision() async throws {
        let departure = ISO8601.parse("2026-08-17T18:00:00+02:00")!
        let arrival = ISO8601.parse("2026-08-17T19:00:00+02:00")!
        let destination = address("nation", "Nation")
        let parser = InMemoryNaturalIntentParser(intent: RouteIntent(
            scope: .journey,
            origin: .currentLocation,
            destinationQuery: "Nation",
            requestedAt: departure,
            datetimeRepresents: .departure,
            requiredModes: [],
            excludedModes: [],
            preferredModes: [],
            alternateTimeConstraint: RouteTimeConstraint(
                requestedAt: arrival,
                meaning: .arrival,
            ),
        ))
        let journeys = OnDeviceJourneyRecorder(results: [.mapPreview])
        let service = makeService(parser: parser, results: [destination], journeys: journeys)

        let result = try await service.submit(.submit(
            query: "Partir après 18 h et arriver avant 19 h à Nation",
            currentLocation: GeoCoordinate(latitude: 48.85, longitude: 2.35),
        ))

        guard case let .needsDecision(_, .timeConflict(first, second)) = result else {
            return XCTFail("Expected a time conflict decision")
        }
        XCTAssertEqual(Set([first, second]), Set([
            RouteTimeConstraint(requestedAt: departure, meaning: .departure),
            RouteTimeConstraint(requestedAt: arrival, meaning: .arrival),
        ]))
        let requests = await journeys.requests
        XCTAssertTrue(requests.isEmpty)
    }

    func testResolvingATimeConflictUsesTheChosenConstraint() async throws {
        let departure = ISO8601.parse("2026-08-17T18:00:00+02:00")!
        let arrival = ISO8601.parse("2026-08-17T19:00:00+02:00")!
        let destination = address("nation", "Nation")
        let draft = NaturalJourneyDraft(
            intent: RouteIntent(
                scope: .journey,
                origin: .currentLocation,
                destinationQuery: "Nation",
                requestedAt: departure,
                datetimeRepresents: .departure,
                requiredModes: [],
                excludedModes: [],
                preferredModes: [],
                alternateTimeConstraint: RouteTimeConstraint(
                    requestedAt: arrival,
                    meaning: .arrival,
                ),
            ),
            origin: nil,
            destination: destination,
        )
        let journeys = OnDeviceJourneyRecorder(results: [.mapPreview])
        let service = makeService(
            parser: InMemoryNaturalIntentParser(),
            results: [destination],
            journeys: journeys,
        )

        let result = try await service.submit(.resolveTimeConflict(
            draft: draft,
            currentLocation: GeoCoordinate(latitude: 48.85, longitude: 2.35),
            keeping: RouteTimeConstraint(requestedAt: arrival, meaning: .arrival),
        ))

        guard case .ready = result else {
            return XCTFail("Expected a ready result")
        }
        let requests = await journeys.requests
        XCTAssertEqual(requests.first?.requestedAt, arrival)
        XCTAssertEqual(requests.first?.datetimeRepresents, .arrival)
    }

    func testSubmitProducesOnDeviceReadyResultAndPlansVerifiedPlaces() async throws {
        let destination = address("nation", "Nation")
        let recorder = OnDeviceJourneyRecorder(results: [.mapPreview])
        let parser = InMemoryNaturalIntentParser(
            intent: intent(destination: "Nation", requestedAt: now, preferredModes: [.bus]),
        )
        let service = makeService(parser: parser, results: [destination], journeys: recorder)
        let coordinate = GeoCoordinate(latitude: 48.85, longitude: 2.35)

        let result = try await service.submit(.submit(
            query: "Nation plutôt en bus",
            currentLocation: coordinate,
        ))

        guard case let .ready(interpretation, _) = result else {
            return XCTFail("Expected a ready result")
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
            requiredModes: [], excludedModes: [], preferredModes: [],
        ))
        let service = makeService(parser: parser) { query in
            query == "gare" ? [first, second] : [destination]
        }

        let result = try await service.submit(.submit(query: "de la gare à Nation", currentLocation: nil))

        guard case let .needsClarification(_, fields) = result else {
            return XCTFail("Expected clarification")
        }
        XCTAssertEqual(fields.first?.target, .origin)
        XCTAssertEqual(fields.first?.candidates, [first, second])
    }

    func testExplicitDateWithoutTimeReturnsTimeClarification() async throws {
        let destination = address("nation", "Nation")
        let tomorrow = ISO8601.parse("2026-08-21T12:00:00+02:00")!
        let parser = InMemoryNaturalIntentParser(intent: RouteIntent(
            scope: .journey,
            origin: .currentLocation,
            destinationQuery: "Nation",
            requestedAt: tomorrow,
            datetimeRepresents: .departure,
            requiredModes: [],
            excludedModes: [],
            preferredModes: [],
            dateWasExplicit: true,
            timeWasExplicit: false,
        ))
        let service = makeService(parser: parser, results: [destination])

        let result = try await service.submit(.submit(
            query: "Je veux aller à Nation demain",
            currentLocation: .init(latitude: 48.85, longitude: 2.35),
        ))

        guard case let .needsClarification(_, fields) = result else {
            return XCTFail("Expected clarification")
        }
        XCTAssertEqual(fields.map(\.target), [.time])
        XCTAssertEqual(fields.first?.question, "À quelle heure veux-tu voyager ?")
    }

    func testPastAnchorForExplicitDateWithoutTimeStillAsksForTheTime() async throws {
        let destination = address("nation", "Nation")
        let todayAnchor = ISO8601.parse("2026-08-17T08:00:00+02:00")!
        let parser = InMemoryNaturalIntentParser(intent: RouteIntent(
            scope: .journey,
            origin: .currentLocation,
            destinationQuery: "Nation",
            requestedAt: todayAnchor,
            datetimeRepresents: .arrival,
            requiredModes: [],
            excludedModes: [],
            preferredModes: [],
            dateWasExplicit: true,
            timeWasExplicit: false,
        ))
        let service = makeService(parser: parser, results: [destination])

        let result = try await service.submit(.submit(
            query: "Aujourd’hui pour Nation",
            currentLocation: .init(latitude: 48.85, longitude: 2.35),
        ))

        guard case let .needsClarification(_, fields) = result else {
            return XCTFail("Expected a missing-time clarification")
        }
        XCTAssertEqual(fields.map(\.target), [.time])
    }

    func testResolvingMissingTimeKeepsTheExplicitDay() async throws {
        let destination = address("nation", "Nation")
        let tomorrow = ISO8601.parse("2026-08-21T12:00:00+02:00")!
        let chosenTime = ISO8601.parse("2026-08-21T08:30:00+02:00")!
        let draft = NaturalJourneyDraft(
            intent: RouteIntent(
                scope: .journey,
                origin: .currentLocation,
                destinationQuery: "Nation",
                requestedAt: tomorrow,
                datetimeRepresents: .arrival,
                requiredModes: [],
                excludedModes: [],
                preferredModes: [],
                dateWasExplicit: true,
                timeWasExplicit: false,
            ),
            origin: nil,
            destination: destination,
        )
        let journeys = OnDeviceJourneyRecorder(results: [.mapPreview])
        let service = makeService(
            parser: InMemoryNaturalIntentParser(parsingError: .modelFailed),
            journeys: journeys,
            results: { _ in [destination] },
        )

        let result = try await service.submit(.resolve(
            draft: draft,
            currentLocation: GeoCoordinate(latitude: 48.85, longitude: 2.35),
            origin: nil,
            destination: nil,
            requestedAt: chosenTime,
            datetimeRepresents: .arrival,
        ))

        guard case let .ready(interpretation, _) = result else {
            return XCTFail("Expected a ready result")
        }
        XCTAssertEqual(interpretation.requestedAt, chosenTime)
        XCTAssertEqual(interpretation.datetimeRepresents, .arrival)
    }

    func testMissingDateAndTimeSearchesFromNow() async throws {
        let destination = address("nation", "Nation")
        let parser = InMemoryNaturalIntentParser(intent: RouteIntent(
            scope: .journey,
            origin: .currentLocation,
            destinationQuery: "Nation",
            requestedAt: nil,
            datetimeRepresents: .departure,
            requiredModes: [],
            excludedModes: [],
            preferredModes: [],
            dateWasExplicit: false,
            timeWasExplicit: false,
        ))
        let journeys = OnDeviceJourneyRecorder(results: [.mapPreview])
        let service = makeService(parser: parser, results: [destination], journeys: journeys)

        _ = try await service.submit(.submit(
            query: "Je veux aller à Nation",
            currentLocation: .init(latitude: 48.85, longitude: 2.35),
        ))

        let requests = await journeys.requests
        XCTAssertEqual(requests.first?.requestedAt, now)
    }

    func testJourneyNetworkFailurePreservesTheVerifiedInterpretation() async throws {
        let destination = address("nation", "Nation")
        let parser = InMemoryNaturalIntentParser(intent: RouteIntent(
            scope: .journey,
            origin: .currentLocation,
            destinationQuery: "Nation",
            requestedAt: now,
            datetimeRepresents: .arrival,
            requiredModes: [],
            excludedModes: [.rer],
            preferredModes: [],
        ))
        let service = makeService(
            parser: parser,
            journeys: FailingOnDeviceJourneyRepository(),
            results: { _ in [destination] },
        )

        let result = try await service.submit(.submit(
            query: "Nation avant 9 h, sans RER",
            currentLocation: GeoCoordinate(latitude: 48.85, longitude: 2.35),
        ))

        guard case let .networkUnavailable(interpretation) = result else {
            return XCTFail("Expected a recoverable network state")
        }
        XCTAssertEqual(interpretation.destinationResult, destination)
        XCTAssertEqual(interpretation.excludedModes, [.rer])
    }

    func testMissingArrivalJourneyNeverFallsBackToDepartureNow() async throws {
        let destination = address("nation", "Nation")
        let parser = InMemoryNaturalIntentParser(intent: RouteIntent(
            scope: .journey,
            origin: .currentLocation,
            destinationQuery: "Nation",
            requestedAt: now.addingTimeInterval(3_600),
            datetimeRepresents: .arrival,
            requiredModes: [],
            excludedModes: [],
            preferredModes: [],
        ))
        let noRoute = JourneyResult(
            status: .noRoute,
            source: nil,
            generatedAt: now,
            journeys: [],
        )
        let journeys = OnDeviceJourneyRecorder(results: [noRoute, .mapPreview])
        let service = makeService(parser: parser, results: [destination], journeys: journeys)

        let result = try await service.submit(.submit(
            query: "Nation avant 10 h",
            currentLocation: GeoCoordinate(latitude: 48.85, longitude: 2.35),
        ))

        guard case .unavailable = result else {
            return XCTFail("Expected the verified arrival search to stay unavailable")
        }
        let requests = await journeys.requests
        XCTAssertEqual(requests.count, 1)
        XCTAssertEqual(requests.first?.datetimeRepresents, .arrival)
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
                requiredModes: [], excludedModes: [], preferredModes: [],
            ),
            origin: nil,
            destination: destination,
        )
        let service = makeService(parser: parser) { query in
            query == "Châtelet" ? [origin] : [destination]
        }

        let result = try await service.submit(.resolve(
            draft: draft,
            currentLocation: nil,
            origin: origin,
            destination: nil,
            requestedAt: nil,
            datetimeRepresents: nil,
        ))

        guard case let .ready(interpretation, _) = result else {
            return XCTFail("Expected a ready result")
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
            requiredModes: [], excludedModes: [], preferredModes: [],
        ))
        let service = makeService(parser: parser)

        let result = try await service.submit(.submit(query: "Quel temps fera-t-il ?", currentLocation: nil))

        guard case let .unsupported(message, examples) = result else {
            return XCTFail("Expected unsupported")
        }
        XCTAssertEqual(message, "Via peut t’aider à préparer un trajet en Île-de-France")
        XCTAssertEqual(examples.count, 2)
    }

    func testMissingCurrentLocationAsksForOrigin() async throws {
        let destination = address("nation", "Nation")
        let parser = InMemoryNaturalIntentParser(intent: intent(
            destination: "Nation",
            requestedAt: now,
        ))
        let service = makeService(parser: parser, results: [destination])

        let result = try await service.submit(.submit(query: "Nation à 10 h", currentLocation: nil))

        guard case let .needsClarification(_, fields) = result else {
            return XCTFail("Expected clarification")
        }
        XCTAssertEqual(fields.first?.target, .origin)
        XCTAssertEqual(fields.first?.question, "D’où pars-tu ?")
    }

    private func makeService(
        parser: any NaturalIntentParsing,
        results: [SearchResult] = [],
        journeys: any JourneyRepository = InMemoryJourneyRepository(result: .mapPreview),
    ) -> OnDeviceNaturalJourneyService {
        makeService(parser: parser, journeys: journeys) { _ in results }
    }

    private func makeService(
        parser: any NaturalIntentParsing,
        journeys: any JourneyRepository = InMemoryJourneyRepository(result: .mapPreview),
        results: @escaping @Sendable (String) -> [SearchResult],
    ) -> OnDeviceNaturalJourneyService {
        let fixedNow = now
        return OnDeviceNaturalJourneyService(
            parser: parser,
            places: OnDevicePlaceResolver { query, _ in
                SearchResponse(results: results(query), addressSource: .ok)
            },
            journeys: journeys,
            now: { fixedNow },
        )
    }

    private func intent(
        destination: String,
        requestedAt: Date?,
        preferredModes: Set<TransitMode> = [],
    ) -> RouteIntent {
        RouteIntent(
            scope: .journey,
            origin: .currentLocation,
            destinationQuery: destination,
            requestedAt: requestedAt,
            datetimeRepresents: .departure,
            requiredModes: [],
            excludedModes: [],
            preferredModes: preferredModes,
        )
    }

    private func station(_ id: String, _ name: String) -> SearchResult {
        .station(.init(
            id: .init(rawValue: id),
            name: name,
            coordinate: .init(latitude: 48.85, longitude: 2.35),
            routes: [],
            distanceMeters: nil,
        ))
    }

    private func address(_ id: String, _ name: String) -> SearchResult {
        .address(.init(
            id: id,
            name: name,
            context: "Paris",
            coordinate: .init(latitude: 48.86, longitude: 2.36),
            distanceMeters: nil,
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

private struct FailingOnDeviceJourneyRepository: JourneyRepository {
    func plan(_: JourneyRequest) async throws -> JourneyResult {
        throw ViaError.transport
    }
}
