@testable import Via
import XCTest

final class OnDeviceNaturalJourneyServiceTests: XCTestCase {
    private let now = ISO8601.parse("2026-08-17T09:00:00+02:00")!

    func testSaintLazareToGareDuNordPlansImmediately() async throws {
        let saintLazare = station("saint-lazare", "Gare Saint-Lazare")
        let gareDuNord = station("gare-du-nord", "Gare du Nord")
        let understanding = ReliableNaturalJourneyUnderstanding(
            localModel: InMemoryNaturalIntentParser(parsingError: .modelNotReady),
            remoteModel: nil,
            savedPlaces: { [] },
            serverFallbackAllowed: { false },
        )
        let journeys = OnDeviceJourneyRecorder(results: [.mapPreview])
        let service = OnDeviceNaturalJourneyService(
            understanding: understanding,
            places: OnDevicePlaceResolver { query, _ in
                let result: SearchResult? = switch OnDevicePlaceResolver.normalize(query) {
                case "gare saint lazare": saintLazare
                case "gare du nord": gareDuNord
                default: nil
                }
                return SearchResponse(results: [result].compactMap { $0 }, addressSource: .ok)
            },
            journeys: journeys,
            now: { [now = now] in now },
        )

        let result = try await service.submit(.submit(
            query: "gare saint lazare pour aller ensuite à gare du nord",
            currentLocation: nil,
        ))

        guard case let .ready(interpretation, _) = result else {
            return XCTFail("Ce trajet explicite doit être planifié sans clarification")
        }
        XCTAssertEqual(interpretation.originResult, saintLazare)
        XCTAssertEqual(interpretation.destinationResult, gareDuNord)
        XCTAssertEqual(interpretation.requestedAt, now)
        XCTAssertEqual(interpretation.datetimeRepresents, JourneyDatetimeRepresents.departure)
        let requests = await journeys.requests
        XCTAssertEqual(requests.count, 1)
        XCTAssertEqual(requests.first?.originStationID, StationID(rawValue: "saint-lazare"))
    }

    func testMissingHomeRequiresDedicatedChoiceWithoutGeocodingItsAlias() async throws {
        let auber = address("auber", "Auber")
        let search = NaturalJourneyQueryRecorder(results: [auber])
        let understanding = ReliableNaturalJourneyUnderstanding(
            localModel: InMemoryNaturalIntentParser(parsingError: .modelNotReady),
            remoteModel: nil,
            savedPlaces: {
                [NaturalJourneySavedPlaceReference(
                    id: "role:home",
                    label: "Maison",
                    kind: .home,
                    result: nil,
                )]
            },
            serverFallbackAllowed: { false },
        )
        let journeys = OnDeviceJourneyRecorder(results: [.mapPreview])
        let service = OnDeviceNaturalJourneyService(
            understanding: understanding,
            places: OnDevicePlaceResolver { query, _ in
                await search.response(for: query)
            },
            journeys: journeys,
            now: { [now = now] in now },
        )

        let result = try await service.submit(.submit(
            query: "rentrez chez moi depuis Auber",
            currentLocation: nil,
        ))

        guard case .needsDecision(
            _,
            .missingSavedPlace(target: .destination, kind: .home)
        ) = result else {
            return XCTFail("Maison absente doit déclencher le choix dédié")
        }
        let queries = await search.queries
        XCTAssertFalse(queries.contains { OnDevicePlaceResolver.normalize($0) == "chez moi" })
        XCTAssertFalse(queries.contains { OnDevicePlaceResolver.normalize($0) == "maison" })
        let requests = await journeys.requests
        XCTAssertTrue(requests.isEmpty)
    }

    func testUnderstandingConflictStopsBeforePlaceResolutionAndPlanning() async throws {
        let intent = RouteIntent(
            scope: .journey,
            origin: .place(query: "Auber"),
            destinationQuery: "Nation",
            requestedAt: now,
            datetimeRepresents: .departure,
            requiredModes: [],
            excludedModes: [],
            preferredModes: [],
        )
        let transition = NaturalJourneyTransition(
            state: NaturalJourneyDialogueState(intent: intent),
            changedFields: [.origin, .destination],
            conflicts: [NaturalJourneyConflict(
                field: .origin,
                groundedEvidence: "depuis Auber",
                proposedEvidence: "Nation",
            )],
        )
        let search = NaturalJourneyQueryRecorder(results: [])
        let journeys = OnDeviceJourneyRecorder(results: [.mapPreview])
        let service = OnDeviceNaturalJourneyService(
            understanding: FixedNaturalJourneyUnderstanding(transition: transition),
            places: OnDevicePlaceResolver { query, _ in
                await search.response(for: query)
            },
            journeys: journeys,
            now: { [now = now] in now },
        )

        let result = try await service.submit(.submit(
            query: "Depuis Auber vers Nation",
            currentLocation: nil,
        ))

        guard case .needsDecision(_, .interpretationConflict(let fields)) = result else {
            return XCTFail("Un désaccord d’ancre doit être visible")
        }
        XCTAssertEqual(fields, [.origin])
        let queries = await search.queries
        let requests = await journeys.requests
        XCTAssertTrue(queries.isEmpty)
        XCTAssertTrue(requests.isEmpty)
    }

    func testUnexplainedTextMustBeAcknowledgedBeforePlanning() async throws {
        let intent = RouteIntent(
            scope: .journey,
            origin: .currentLocation,
            destinationQuery: "Nation",
            requestedAt: now,
            datetimeRepresents: .departure,
            requiredModes: [],
            excludedModes: [],
            preferredModes: [],
            originWasExplicit: true,
        )
        let transition = NaturalJourneyTransition(
            state: NaturalJourneyDialogueState(intent: intent),
            changedFields: [.destination],
            conflicts: [],
            unexplainedText: "sans correspondance compliquée",
        )
        let journeys = OnDeviceJourneyRecorder(results: [.mapPreview])
        let service = OnDeviceNaturalJourneyService(
            understanding: FixedNaturalJourneyUnderstanding(transition: transition),
            places: OnDevicePlaceResolver { _, _ in
                SearchResponse(results: [], addressSource: .ok)
            },
            journeys: journeys,
            now: { [now = now] in now },
        )

        let result = try await service.submit(.submit(
            query: "Nation sans correspondance compliquée",
            currentLocation: .init(latitude: 48.85, longitude: 2.35),
        ))

        guard case .needsDecision(_, .unexplainedText(let text)) = result else {
            return XCTFail("Le fragment inexpliqué ne doit pas être ignoré")
        }
        XCTAssertEqual(text, "sans correspondance compliquée")
        let requests = await journeys.requests
        XCTAssertTrue(requests.isEmpty)
    }

    func testCustomAliasCollisionShowsSavedAndPublicCandidates() async throws {
        let saved = address("saved-bastille", "Mon Bastille")
        let publicPlace = address("public-bastille", "Bastille")
        let reference = NaturalJourneySavedPlaceReference(
            id: "custom:bastille",
            label: "Bastille",
            kind: .custom,
            result: saved,
        )
        let intent = RouteIntent(
            scope: .journey,
            origin: .currentLocation,
            destinationQuery: nil,
            requestedAt: now,
            datetimeRepresents: .departure,
            requiredModes: [],
            excludedModes: [],
            preferredModes: [],
            originWasExplicit: true,
        ).replacingPlaces(destination: .saved(reference), replaceDestination: true)
        let transition = NaturalJourneyTransition(
            state: NaturalJourneyDialogueState(intent: intent),
            changedFields: [.destination],
            conflicts: [],
        )
        let journeys = OnDeviceJourneyRecorder(results: [.mapPreview])
        let service = OnDeviceNaturalJourneyService(
            understanding: FixedNaturalJourneyUnderstanding(transition: transition),
            places: OnDevicePlaceResolver { _, _ in
                SearchResponse(results: [publicPlace], addressSource: .ok)
            },
            journeys: journeys,
            now: { [now = now] in now },
        )

        let result = try await service.submit(.submit(
            query: "Va à Bastille",
            currentLocation: .init(latitude: 48.85, longitude: 2.35),
        ))

        guard case let .needsClarification(_, fields) = result else {
            return XCTFail("Une collision d’alias doit être clarifiée")
        }
        XCTAssertEqual(fields.first?.target, .destination)
        XCTAssertEqual(fields.first?.candidates, [saved, publicPlace])
        let requests = await journeys.requests
        XCTAssertTrue(requests.isEmpty)
    }

    func testAmbiguousConversationReferenceAsksInsteadOfGeocodingThere() async throws {
        let previousIntent = RouteIntent(
            scope: .journey,
            originPlace: .query("Auber"),
            destinationPlace: .query("Nation"),
            requestedAt: now,
            datetimeRepresents: .departure,
            requiredModes: [],
            excludedModes: [],
            preferredModes: [],
        )
        var previousState = NaturalJourneyDialogueState(intent: previousIntent)
        previousState[field: .origin] = .confirmed(evidence: "Auber")
        previousState[field: .destination] = .confirmed(evidence: "Nation")
        let draft = NaturalJourneyDraft(
            dialogueState: previousState,
            origin: address("auber", "Auber"),
            destination: address("nation", "Nation"),
        )
        let search = NaturalJourneyQueryRecorder(results: [])
        let journeys = OnDeviceJourneyRecorder(results: [.mapPreview])
        let understanding = ReliableNaturalJourneyUnderstanding(
            localModel: InMemoryNaturalIntentParser(parsingError: .modelNotReady),
            remoteModel: nil,
            savedPlaces: { [] },
            serverFallbackAllowed: { false },
        )
        let service = OnDeviceNaturalJourneyService(
            understanding: understanding,
            places: OnDevicePlaceResolver { query, _ in
                await search.response(for: query)
            },
            journeys: journeys,
            now: { [now = now] in now },
        )

        let result = try await service.submit(.revise(
            query: "pars de là vers Bastille",
            draft: draft,
            currentLocation: nil,
        ))

        guard case let .needsClarification(_, fields) = result else {
            return XCTFail("Une référence sans antécédent unique doit être clarifiée")
        }
        XCTAssertEqual(fields.first?.target, .origin)
        let queries = await search.queries
        let requests = await journeys.requests
        XCTAssertTrue(queries.isEmpty)
        XCTAssertTrue(requests.isEmpty)
    }

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
            parser: InMemoryNaturalIntentParser(intent: draft.intent),
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
            query: "de ma position à Nation plutôt en bus mais sans bus",
            currentLocation: GeoCoordinate(latitude: 48.85, longitude: 2.35),
        ))
        guard case let .needsDecision(_, .modeConflict(mode, choices)) = decision else {
            return XCTFail("Expected a preferred/excluded conflict, got \(decision)")
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

    func testSubmitRecordsOnlyAnonymousInterpretationDuration() async throws {
        let destination = address("nation", "Nation")
        let parser = InMemoryNaturalIntentParser(intent: intent(
            destination: "Nation",
            requestedAt: now,
        ))
        let metrics = InterpretationMetricsRecorder()
        let service = makeService(
            parser: parser,
            results: [destination],
            metrics: metrics,
            metricsNow: { Date(timeIntervalSince1970: 42) },
        )

        _ = try await service.submit(.submit(
            query: "Nation maintenant",
            currentLocation: GeoCoordinate(latitude: 48.85, longitude: 2.35),
        ))

        XCTAssertEqual(metrics.interpretationDurations, [0])
        XCTAssertTrue(metrics.searches.isEmpty)
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

    func testImplicitAmbiguousTimeDefaultsToDepartureNow() async throws {
        let destination = address("nation", "Nation")
        let parser = InMemoryNaturalIntentParser(intent: RouteIntent(
            scope: .journey,
            origin: .currentLocation,
            destinationQuery: "Nation",
            requestedAt: now,
            datetimeRepresents: .ambiguous,
            requiredModes: [],
            excludedModes: [],
            preferredModes: [],
            dateWasExplicit: false,
            timeWasExplicit: false,
            originWasExplicit: true,
        ))
        let journeys = OnDeviceJourneyRecorder(results: [.mapPreview])
        let service = makeService(parser: parser, results: [destination], journeys: journeys)

        let result = try await service.submit(.submit(
            query: "Je veux aller à Nation",
            currentLocation: .init(latitude: 48.85, longitude: 2.35),
        ))

        guard case let .ready(interpretation, _) = result else {
            return XCTFail("Une heure implicite ne doit pas demander départ ou arrivée")
        }
        XCTAssertEqual(interpretation.requestedAt, now)
        XCTAssertEqual(interpretation.datetimeRepresents, .departure)
        let requests = await journeys.requests
        XCTAssertEqual(requests.first?.datetimeRepresents, .departure)
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

    func testGeocodingNetworkFailurePreservesTheLocallyInterpretedDraft() async throws {
        let fixedNow = now
        let intent = RouteIntent(
            scope: .journey,
            origin: .currentLocation,
            destinationQuery: "Nation",
            requestedAt: now,
            datetimeRepresents: .arrival,
            requiredModes: [],
            excludedModes: [.rer],
            preferredModes: [.bus],
            originWasExplicit: true,
        )
        let service = OnDeviceNaturalJourneyService(
            parser: InMemoryNaturalIntentParser(intent: intent),
            places: OnDevicePlaceResolver { _, _ in throw ViaError.transport },
            journeys: InMemoryJourneyRepository(result: .mapPreview),
            now: { fixedNow },
        )

        let result = try await service.submit(.submit(
            query: "Nation avant 9 h, sans RER, plutôt en bus",
            currentLocation: GeoCoordinate(latitude: 48.85, longitude: 2.35),
        ))

        guard case let .networkUnavailableDraft(draft) = result else {
            return XCTFail("Expected the interpreted draft to survive geocoding failure")
        }
        XCTAssertEqual(draft.intent.destinationQuery, "Nation")
        XCTAssertEqual(draft.intent.requestedAt, now)
        XCTAssertEqual(draft.intent.datetimeRepresents, .arrival)
        XCTAssertEqual(draft.intent.excludedModes, [.rer])
        XCTAssertEqual(draft.intent.preferredModes, [.bus])
    }

    func testMissingArrivalJourneyNeverFallsBackToDepartureNow() async throws {
        let destination = address("nation", "Nation")
        let parser = InMemoryNaturalIntentParser(intent: RouteIntent(
            scope: .journey,
            origin: .currentLocation,
            destinationQuery: "Nation",
            requestedAt: now.addingTimeInterval(3600),
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

    func testLineStatusQuestionOpensTheOfficialMatchedLineWithoutPlanningAJourney() async throws {
        let journeys = OnDeviceJourneyRecorder(results: [.mapPreview])
        let parser = InMemoryNaturalIntentParser(intent: RouteIntent(
            scope: .lineStatus,
            origin: .currentLocation,
            destinationQuery: nil,
            requestedAt: now,
            datetimeRepresents: .departure,
            requiredModes: [],
            excludedModes: [],
            preferredModes: [],
            originWasExplicit: false,
            lineStatus: NaturalLineStatusIntent(
                kind: .specific,
                code: "4",
                mode: .metro,
                evidence: "métro 4",
            ),
        ))
        let service = OnDeviceNaturalJourneyService(
            parser: parser,
            places: OnDevicePlaceResolver { _, _ in .init(results: [], addressSource: .ok) },
            journeys: journeys,
            lineStatuses: PreviewLineStatusRepository(),
            now: { [now = now] in now },
        )

        let result = try await service.submit(.submit(
            query: "Y a-t-il des perturbations sur le métro 4 ?",
            currentLocation: nil,
        ))

        guard case .lineStatus(let navigation) = result else {
            return XCTFail("Expected a line-status navigation")
        }
        XCTAssertEqual(navigation.route?.route.shortName, "4")
        XCTAssertEqual(navigation.route?.condition, .disrupted)
        XCTAssertEqual(navigation.mode, .metro)
        let requests = await journeys.requests
        XCTAssertTrue(requests.isEmpty)
    }

    func testDisruptionOverviewOpensTheFilteredLinesBoard() async throws {
        let parser = InMemoryNaturalIntentParser(intent: RouteIntent(
            scope: .lineStatus,
            origin: .currentLocation,
            destinationQuery: nil,
            requestedAt: now,
            datetimeRepresents: .departure,
            requiredModes: [],
            excludedModes: [],
            preferredModes: [],
            originWasExplicit: false,
            lineStatus: NaturalLineStatusIntent(
                kind: .disruptions,
                code: "",
                mode: .rer,
                evidence: "RER sont perturbés",
            ),
        ))
        let service = OnDeviceNaturalJourneyService(
            parser: parser,
            places: OnDevicePlaceResolver { _, _ in .init(results: [], addressSource: .ok) },
            journeys: InMemoryJourneyRepository(result: .mapPreview),
            now: { [now = now] in now },
        )

        let result = try await service.submit(.submit(
            query: "Quels RER sont perturbés ?",
            currentLocation: nil,
        ))

        guard case .lineStatus(let navigation) = result else {
            return XCTFail("Expected a filtered line board")
        }
        XCTAssertNil(navigation.route)
        XCTAssertEqual(navigation.mode, .rer)
        XCTAssertTrue(navigation.disruptionsOnly)
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

    func testMissingDestinationAlwaysAsksForOne() async throws {
        let parser = InMemoryNaturalIntentParser(intent: RouteIntent(
            scope: .journey,
            origin: .currentLocation,
            destinationQuery: nil,
            requestedAt: now,
            datetimeRepresents: .departure,
            requiredModes: [],
            excludedModes: [],
            preferredModes: [],
            originWasExplicit: true,
        ))
        let service = makeService(parser: parser)

        let result = try await service.submit(.submit(
            query: "Je veux y aller maintenant",
            currentLocation: GeoCoordinate(latitude: 48.85, longitude: 2.35),
        ))

        guard case let .needsClarification(_, fields) = result else {
            return XCTFail("Expected a destination clarification")
        }
        XCTAssertEqual(fields.map(\.target), [.destination])
        XCTAssertEqual(fields.first?.question, "Où veux-tu aller ?")
    }

    func testAmbiguousTimeMeaningAlwaysAsksDepartureOrArrival() async throws {
        let destination = address("nation", "Nation")
        let parser = InMemoryNaturalIntentParser(intent: RouteIntent(
            scope: .journey,
            origin: .currentLocation,
            destinationQuery: "Nation",
            requestedAt: now,
            datetimeRepresents: .ambiguous,
            requiredModes: [],
            excludedModes: [],
            preferredModes: [],
            originWasExplicit: true,
        ))
        let service = makeService(parser: parser, results: [destination])

        let result = try await service.submit(.submit(
            query: "Nation à 10 h",
            currentLocation: GeoCoordinate(latitude: 48.85, longitude: 2.35),
        ))

        guard case let .needsClarification(_, fields) = result else {
            return XCTFail("Expected a time-meaning clarification")
        }
        XCTAssertEqual(fields.map(\.target), [.time])
        XCTAssertEqual(fields.first?.question, "Tu veux partir ou arriver à cette heure ?")
    }

    private func makeService(
        parser: any NaturalIntentParsing,
        results: [SearchResult] = [],
        journeys: any JourneyRepository = InMemoryJourneyRepository(result: .mapPreview),
        metrics: any NaturalJourneyMetricsRecording = NoOpNaturalJourneyMetrics(),
        metricsNow: @escaping @Sendable () -> Date = { .now },
    ) -> OnDeviceNaturalJourneyService {
        makeService(
            parser: parser,
            journeys: journeys,
            metrics: metrics,
            metricsNow: metricsNow,
        ) { _ in results }
    }

    private func makeService(
        parser: any NaturalIntentParsing,
        journeys: any JourneyRepository = InMemoryJourneyRepository(result: .mapPreview),
        metrics: any NaturalJourneyMetricsRecording = NoOpNaturalJourneyMetrics(),
        metricsNow: @escaping @Sendable () -> Date = { .now },
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
            metrics: metrics,
            metricsNow: metricsNow,
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

private final class InterpretationMetricsRecorder: NaturalJourneyMetricsRecording, @unchecked Sendable {
    private let lock = NSLock()
    private var recordedInterpretationDurations: [Int] = []
    private var recordedSearches: [NaturalJourneyMetric] = []

    var interpretationDurations: [Int] {
        lock.withLock { recordedInterpretationDurations }
    }

    var searches: [NaturalJourneyMetric] {
        lock.withLock { recordedSearches }
    }

    func recordInterpretation(durationMilliseconds: Int) {
        lock.withLock {
            recordedInterpretationDurations.append(durationMilliseconds)
        }
    }

    func recordSearch(_ metric: NaturalJourneyMetric) {
        lock.withLock {
            recordedSearches.append(metric)
        }
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

private actor NaturalJourneyQueryRecorder {
    private(set) var queries: [String] = []
    let results: [SearchResult]

    init(results: [SearchResult]) {
        self.results = results
    }

    func response(for query: String) -> SearchResponse {
        queries.append(query)
        return SearchResponse(results: results, addressSource: .ok)
    }
}

private struct FixedNaturalJourneyUnderstanding: NaturalJourneyUnderstanding {
    let transition: NaturalJourneyTransition

    var availability: NaturalLanguageAvailability { .available }

    func interpret(
        _: NaturalJourneyTurn,
        state _: NaturalJourneyDialogueState?
    ) async throws -> NaturalJourneyTransition {
        transition
    }
}

private struct FailingOnDeviceJourneyRepository: JourneyRepository {
    func plan(_: JourneyRequest) async throws -> JourneyResult {
        throw ViaError.transport
    }
}
