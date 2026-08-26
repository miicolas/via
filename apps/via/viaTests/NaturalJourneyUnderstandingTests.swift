@testable import Via
import XCTest

final class NaturalJourneyUnderstandingTests: XCTestCase {
    func testShortReplyFillsTheOriginClarificationWithoutCallingAModel() async throws {
        let previousIntent = RouteIntent(
            scope: .journey,
            originPlace: .currentLocation,
            destinationPlace: .query("Bonne Nouvelle"),
            requestedAt: ISO8601.parse("2026-08-26T18:00:00+02:00")!,
            datetimeRepresents: .departure,
            requiredModes: [],
            excludedModes: [],
            preferredModes: [],
            dateWasExplicit: false,
            timeWasExplicit: false,
            originWasExplicit: false,
        )
        var previous = NaturalJourneyDialogueState(intent: previousIntent)
        previous[field: .destination] = .grounded(
            evidence: "Bonne Nouvelle",
            provenance: .deterministic,
        )
        let understanding = ReliableNaturalJourneyUnderstanding(
            localModel: InMemoryNaturalIntentParser(parsingError: .modelNotReady),
            remoteModel: nil,
            savedPlaces: { [] },
            serverFallbackAllowed: { false },
        )

        let transition = try await understanding.interpret(
            NaturalJourneyTurn(
                phrase: "Chatou",
                locale: Locale(identifier: "fr_FR"),
                now: ISO8601.parse("2026-08-26T18:01:00+02:00")!,
                focusedField: .origin,
            ),
            state: previous,
        )

        XCTAssertEqual(transition.state.intent.originPlace, .query("Chatou"))
        XCTAssertEqual(
            transition.state.intent.destinationPlace,
            .query("Bonne Nouvelle"),
        )
        XCTAssertEqual(transition.changedFields, [.origin])
        XCTAssertTrue(transition.conflicts.isEmpty)
        XCTAssertEqual(transition.state.processingPath, .deterministic)
    }

    func testExplicitAuberToHomeIsGroundedWithoutCallingAModel() async throws {
        let home = NaturalJourneySavedPlaceReference(
            id: "home",
            label: "Maison",
            kind: .home,
            result: .previewAddress,
        )
        let model = InMemoryNaturalIntentParser(parsingError: .modelNotReady)
        let understanding = ReliableNaturalJourneyUnderstanding(
            localModel: model,
            remoteModel: nil,
            savedPlaces: { [home] },
            serverFallbackAllowed: { false },
        )

        let transition = try await understanding.interpret(
            NaturalJourneyTurn(
                phrase: "rentrez chez moi depuis Auber",
                locale: Locale(identifier: "fr_FR"),
                now: ISO8601.parse("2026-08-26T18:00:00+02:00")!,
            ),
            state: nil,
        )

        XCTAssertEqual(transition.state.intent.originPlace, .query("Auber"))
        XCTAssertEqual(transition.state.intent.destinationPlace, .saved(home))
        XCTAssertEqual(
            transition.state[field: .origin],
            .grounded(evidence: "depuis Auber", provenance: .deterministic),
        )
        XCTAssertEqual(
            transition.state[field: .destination],
            .grounded(evidence: "chez moi", provenance: .deterministic),
        )
        XCTAssertTrue(transition.conflicts.isEmpty)
    }

    func testEnglishAuberToHomeUsesTheSameDeterministicContract() async throws {
        let home = NaturalJourneySavedPlaceReference(
            id: "home",
            label: "Home",
            kind: .home,
            result: .previewAddress,
        )
        let understanding = ReliableNaturalJourneyUnderstanding(
            localModel: InMemoryNaturalIntentParser(parsingError: .modelNotReady),
            remoteModel: nil,
            savedPlaces: { [home] },
            serverFallbackAllowed: { false },
        )

        let transition = try await understanding.interpret(
            NaturalJourneyTurn(
                phrase: "get me home from Auber",
                locale: Locale(identifier: "en_US"),
                now: ISO8601.parse("2026-08-26T18:00:00+02:00")!,
            ),
            state: nil,
        )

        XCTAssertEqual(transition.state.intent.originPlace, .query("Auber"))
        XCTAssertEqual(transition.state.intent.destinationPlace, .saved(home))
        XCTAssertTrue(transition.conflicts.isEmpty)
    }

    func testSequentialJourneyWordingPreservesStationNamesAndDoesNotInventATime() async throws {
        let understanding = ReliableNaturalJourneyUnderstanding(
            localModel: InMemoryNaturalIntentParser(parsingError: .modelNotReady),
            remoteModel: nil,
            savedPlaces: { [] },
            serverFallbackAllowed: { false },
        )

        let transition = try await understanding.interpret(
            NaturalJourneyTurn(
                phrase: "gare saint lazare pour aller ensuite à gare du nord",
                locale: Locale(identifier: "fr_FR"),
                now: ISO8601.parse("2026-08-26T09:10:00+02:00")!,
            ),
            state: nil,
        )

        XCTAssertEqual(transition.state.intent.originPlace, .query("gare saint lazare"))
        XCTAssertEqual(transition.state.intent.destinationPlace, .query("gare du nord"))
        XCTAssertEqual(transition.state.intent.datetimeRepresents, .departure)
        XCTAssertFalse(transition.state.intent.dateWasExplicit)
        XCTAssertFalse(transition.state.intent.timeWasExplicit)
        XCTAssertNil(transition.state.intent.alternateTimeConstraint)
        XCTAssertEqual(transition.state.processingPath, .deterministic)
        XCTAssertTrue(transition.conflicts.isEmpty)
    }

    func testSavedPlaceAfterFromIsOriginAndIsNeverInverted() async throws {
        let home = NaturalJourneySavedPlaceReference(
            id: "home",
            label: "Maison",
            kind: .home,
            result: .previewAddress,
        )
        let understanding = ReliableNaturalJourneyUnderstanding(
            localModel: InMemoryNaturalIntentParser(parsingError: .modelNotReady),
            remoteModel: nil,
            savedPlaces: { [home] },
            serverFallbackAllowed: { false },
        )

        let transition = try await understanding.interpret(
            NaturalJourneyTurn(
                phrase: "va de chez moi vers Auber",
                locale: Locale(identifier: "fr_FR"),
                now: ISO8601.parse("2026-08-26T18:00:00+02:00")!,
            ),
            state: nil,
        )

        XCTAssertEqual(transition.state.intent.originPlace, .saved(home))
        XCTAssertEqual(transition.state.intent.destinationPlace, .query("Auber"))
    }

    func testCommonTypoInOriginMarkerStillGroundsTheCriticalJourney() async throws {
        let home = NaturalJourneySavedPlaceReference(
            id: "home",
            label: "Maison",
            kind: .home,
            result: .previewAddress,
        )
        let understanding = ReliableNaturalJourneyUnderstanding(
            localModel: InMemoryNaturalIntentParser(parsingError: .modelNotReady),
            remoteModel: nil,
            savedPlaces: { [home] },
            serverFallbackAllowed: { false },
        )

        let transition = try await understanding.interpret(
            NaturalJourneyTurn(
                phrase: "rentre chez moi depui Auber",
                locale: Locale(identifier: "fr_FR"),
                now: ISO8601.parse("2026-08-26T18:00:00+02:00")!,
            ),
            state: nil,
        )

        XCTAssertEqual(transition.state.intent.originPlace, .query("Auber"))
        XCTAssertEqual(transition.state.intent.destinationPlace, .saved(home))
    }

    func testLastServiceAuberToHomeAlsoBypassesTheModelWithoutInventingAnHour() async throws {
        let home = NaturalJourneySavedPlaceReference(
            id: "home",
            label: "Maison",
            kind: .home,
            result: .previewAddress,
        )
        let understanding = ReliableNaturalJourneyUnderstanding(
            localModel: InMemoryNaturalIntentParser(parsingError: .modelNotReady),
            remoteModel: nil,
            savedPlaces: { [home] },
            serverFallbackAllowed: { false },
        )

        let transition = try await understanding.interpret(
            NaturalJourneyTurn(
                phrase: "dernier train pour rentrer chez moi depuis Auber",
                locale: Locale(identifier: "fr_FR"),
                now: ISO8601.parse("2026-08-26T18:00:00+02:00")!,
            ),
            state: nil,
        )

        XCTAssertEqual(transition.state.intent.timeAnchor, .lastOfDay)
        XCTAssertFalse(transition.state.intent.timeWasExplicit)
        XCTAssertNil(transition.state.intent.alternateTimeConstraint)
    }

    func testTrailingTomorrowIsNeverAbsorbedIntoTheDestinationName() async throws {
        let tomorrow = ISO8601.parse("2026-08-27T09:00:00+02:00")!
        let modelIntent = RouteIntent(
            scope: .journey,
            origin: .place(query: "Versailles"),
            destinationQuery: "Paris",
            requestedAt: tomorrow,
            datetimeRepresents: .departure,
            requiredModes: [],
            excludedModes: [],
            preferredModes: [],
            dateWasExplicit: true,
            timeWasExplicit: false,
        )
        let understanding = ReliableNaturalJourneyUnderstanding(
            localModel: InMemoryNaturalIntentParser(intent: modelIntent),
            remoteModel: nil,
            savedPlaces: { [] },
            serverFallbackAllowed: { false },
        )

        let transition = try await understanding.interpret(
            NaturalJourneyTurn(
                phrase: "De Versailles à Paris demain",
                locale: Locale(identifier: "fr_FR"),
                now: ISO8601.parse("2026-08-26T18:00:00+02:00")!,
            ),
            state: nil,
        )

        XCTAssertEqual(transition.state.intent.originPlace, .query("Versailles"))
        XCTAssertEqual(transition.state.intent.destinationPlace, .query("Paris"))
        XCTAssertEqual(transition.state.intent.requestedAt, tomorrow)
        XCTAssertEqual(transition.state.processingPath, .localModel)
    }

    func testExplicitModeConstraintStaysLockedWhenTheModelOmitsIt() async throws {
        let modelIntent = RouteIntent(
            scope: .journey,
            origin: .place(query: "Auber"),
            destinationQuery: "Nation",
            requestedAt: ISO8601.parse("2026-08-27T09:00:00+02:00")!,
            datetimeRepresents: .departure,
            requiredModes: [],
            excludedModes: [],
            preferredModes: [],
            dateWasExplicit: true,
            timeWasExplicit: false,
        )
        let understanding = ReliableNaturalJourneyUnderstanding(
            localModel: InMemoryNaturalIntentParser(intent: modelIntent),
            remoteModel: nil,
            savedPlaces: { [] },
            serverFallbackAllowed: { false },
        )

        let transition = try await understanding.interpret(
            NaturalJourneyTurn(
                phrase: "De Auber à Nation demain sans prendre le RER",
                locale: Locale(identifier: "fr_FR"),
                now: ISO8601.parse("2026-08-26T18:00:00+02:00")!,
            ),
            state: nil,
        )

        XCTAssertEqual(transition.state.intent.excludedModes, [.rer])
        XCTAssertEqual(
            transition.state[field: .modes],
            .grounded(evidence: "sans prendre le RER", provenance: .deterministic),
        )
        XCTAssertTrue(transition.conflicts.isEmpty)
    }

    func testPronounWithoutConfirmedContextStaysAConversationReference() async throws {
        let understanding = ReliableNaturalJourneyUnderstanding(
            localModel: InMemoryNaturalIntentParser(parsingError: .modelNotReady),
            remoteModel: nil,
            savedPlaces: { [] },
            serverFallbackAllowed: { false },
        )

        let transition = try await understanding.interpret(
            NaturalJourneyTurn(
                phrase: "je veux y aller",
                locale: Locale(identifier: "fr_FR"),
                now: ISO8601.parse("2026-08-26T18:00:00+02:00")!,
            ),
            state: nil,
        )

        XCTAssertEqual(
            transition.state.intent.destinationPlace,
            .reference(.uniquelyConfirmedPlace),
        )
        XCTAssertEqual(transition.state.processingPath, .deterministic)
    }

    func testPronounUsesAUniqueLockedPlaceFromTheCurrentSearch() async throws {
        let previousIntent = RouteIntent(
            scope: .journey,
            originPlace: .currentLocation,
            destinationPlace: .query("Nation"),
            requestedAt: ISO8601.parse("2026-08-26T18:00:00+02:00")!,
            datetimeRepresents: .departure,
            requiredModes: [],
            excludedModes: [],
            preferredModes: [],
            originWasExplicit: false,
        )
        var previous = NaturalJourneyDialogueState(intent: previousIntent)
        previous[field: .destination] = .confirmed(evidence: "Nation")
        let understanding = ReliableNaturalJourneyUnderstanding(
            localModel: InMemoryNaturalIntentParser(parsingError: .modelNotReady),
            remoteModel: nil,
            savedPlaces: { [] },
            serverFallbackAllowed: { false },
        )

        let transition = try await understanding.interpret(
            NaturalJourneyTurn(
                phrase: "pars de là vers Bastille",
                locale: Locale(identifier: "fr_FR"),
                now: ISO8601.parse("2026-08-26T18:00:00+02:00")!,
            ),
            state: previous,
        )

        XCTAssertEqual(transition.state.intent.originPlace, .query("Nation"))
        XCTAssertEqual(transition.state.intent.destinationPlace, .query("Bastille"))
        XCTAssertEqual(transition.changedFields, [.origin, .destination])
    }

    func testAuberToHomePlansWithTheSavedPlaceWithoutGeocodingItsAlias() async throws {
        let auber = SearchResult.station(StationSearchResult(
            id: StationID(rawValue: "stop_auber"),
            name: "Auber",
            coordinate: .init(latitude: 48.872, longitude: 2.329),
            routes: [],
            distanceMeters: nil,
        ))
        let home = SearchResult.address(AddressSearchResult(
            id: "home-address",
            name: "Maison",
            context: "Paris",
            coordinate: .init(latitude: 48.85, longitude: 2.31),
            distanceMeters: nil,
        ))
        let placeSearch = NaturalJourneyPlaceSearchRecorder(result: auber)
        let journeys = NaturalJourneyPlanningRecorder()
        let understanding = ReliableNaturalJourneyUnderstanding(
            localModel: InMemoryNaturalIntentParser(parsingError: .modelNotReady),
            remoteModel: nil,
            savedPlaces: {
                [NaturalJourneySavedPlaceReference(
                    id: "home",
                    label: "Maison",
                    kind: .home,
                    result: home,
                )]
            },
            serverFallbackAllowed: { false },
        )
        let service = OnDeviceNaturalJourneyService(
            understanding: understanding,
            places: OnDevicePlaceResolver { query, _ in
                await placeSearch.search(query)
            },
            journeys: journeys,
            now: { ISO8601.parse("2026-08-26T18:00:00+02:00")! },
        )

        let result = try await service.submit(.submit(
            query: "rentrez chez moi depuis Auber",
            currentLocation: nil,
        ))

        guard case let .ready(interpretation, _) = result else {
            return XCTFail("Le trajet explicite doit être exécuté sans clarification")
        }
        XCTAssertEqual(interpretation.originResult, auber)
        XCTAssertEqual(interpretation.destinationResult, home)
        let searchedQueries = await placeSearch.queries
        XCTAssertEqual(searchedQueries, ["Auber"])
        let plannedRequests = await journeys.requests
        let request = try XCTUnwrap(plannedRequests.first)
        XCTAssertEqual(request.origin, auber.coordinate)
        XCTAssertEqual(request.destination.coordinate, home.coordinate)
    }

    func testNaturalOrderLastServicePlansWithOnlyTheStationNameSearched() async throws {
        let chatelet = SearchResult.station(StationSearchResult(
            id: StationID(rawValue: "stop_chatelet"),
            name: "Châtelet",
            coordinate: .init(latitude: 48.858, longitude: 2.347),
            routes: [],
            distanceMeters: nil,
        ))
        let home = SearchResult.address(AddressSearchResult(
            id: "home-address",
            name: "Maison",
            context: "Paris",
            coordinate: .init(latitude: 48.85, longitude: 2.31),
            distanceMeters: nil,
        ))
        let placeSearch = NaturalJourneyPlaceSearchRecorder(result: chatelet)
        let journeys = NaturalJourneyPlanningRecorder()
        let understanding = ReliableNaturalJourneyUnderstanding(
            localModel: InMemoryNaturalIntentParser(parsingError: .modelNotReady),
            remoteModel: nil,
            savedPlaces: {
                [NaturalJourneySavedPlaceReference(
                    id: "home",
                    label: "Maison",
                    kind: .home,
                    result: home,
                )]
            },
            serverFallbackAllowed: { false },
        )
        let service = OnDeviceNaturalJourneyService(
            understanding: understanding,
            places: OnDevicePlaceResolver { query, _ in
                await placeSearch.search(query)
            },
            journeys: journeys,
            now: { ISO8601.parse("2026-08-26T18:00:00+02:00")! },
        )

        let result = try await service.submit(.submit(
            query: "rentrer chez moi depuis Châtelet ce soir avec le dernier train",
            currentLocation: nil,
        ))

        guard case let .ready(interpretation, _) = result else {
            return XCTFail("La demande naturelle complète doit être exécutée sans clarification")
        }
        XCTAssertEqual(interpretation.originResult, chatelet)
        XCTAssertEqual(interpretation.destinationResult, home)
        XCTAssertEqual(interpretation.timeAnchor, .lastOfDay)
        let searchedQueries = await placeSearch.queries
        XCTAssertEqual(searchedQueries, ["Châtelet"])
        let plannedRequests = await journeys.requests
        let request = try XCTUnwrap(plannedRequests.first)
        XCTAssertEqual(request.origin, chatelet.coordinate)
        XCTAssertEqual(request.destination.coordinate, home.coordinate)
        XCTAssertEqual(request.timeAnchor, .lastOfDay)
    }

    func testAConflictingModelCannotReplaceAnExplicitOrigin() async throws {
        let inverted = RouteIntent(
            scope: .journey,
            origin: .place(query: "Nation"),
            destinationQuery: "Auber",
            requestedAt: ISO8601.parse("2026-08-26T18:00:00+02:00")!,
            datetimeRepresents: .departure,
            requiredModes: [],
            excludedModes: [],
            preferredModes: [],
        )
        let understanding = ReliableNaturalJourneyUnderstanding(
            localModel: InMemoryNaturalIntentParser(intent: inverted),
            remoteModel: nil,
            savedPlaces: { [] },
            serverFallbackAllowed: { false },
        )

        let transition = try await understanding.interpret(
            NaturalJourneyTurn(
                phrase: "depuis Auber, trouve un trajet",
                locale: Locale(identifier: "fr_FR"),
                now: ISO8601.parse("2026-08-26T18:00:00+02:00")!,
            ),
            state: nil,
        )

        XCTAssertEqual(transition.state.intent.originPlace, .query("Auber"))
        XCTAssertEqual(transition.conflicts.map(\.field), [.origin])
    }

    func testDeterministicArrivalWordingSurfacesAModelTimeDisagreement() async throws {
        let intent = RouteIntent(
            scope: .journey,
            origin: .currentLocation,
            destinationQuery: "Nation",
            requestedAt: ISO8601.parse("2026-08-27T09:00:00+02:00")!,
            datetimeRepresents: .departure,
            requiredModes: [],
            excludedModes: [],
            preferredModes: [],
            dateWasExplicit: true,
            timeWasExplicit: true,
            originWasExplicit: false,
        )
        let understanding = ReliableNaturalJourneyUnderstanding(
            localModel: EvidenceNaturalIntentParser(proposal: NaturalIntentProposal(
                intent: intent,
                destinationEvidence: "Nation",
                timeEvidence: "arriver à Nation avant 9 h",
            )),
            remoteModel: nil,
            savedPlaces: { [] },
            serverFallbackAllowed: { false },
        )

        let transition = try await understanding.interpret(
            NaturalJourneyTurn(
                phrase: "arriver à Nation avant 9 h demain",
                locale: Locale(identifier: "fr_FR"),
                now: ISO8601.parse("2026-08-26T18:00:00+02:00")!,
            ),
            state: nil,
        )

        XCTAssertEqual(transition.state.intent.datetimeRepresents, .arrival)
        XCTAssertEqual(transition.conflicts.map(\.field), [.time])
    }

    func testAnExplicitCorrectionReplacesOnlyTheNamedField() async throws {
        let previousIntent = RouteIntent(
            scope: .journey,
            originPlace: .query("Auber"),
            destinationPlace: .query("Nation"),
            requestedAt: ISO8601.parse("2026-08-26T18:00:00+02:00")!,
            datetimeRepresents: .departure,
            requiredModes: [],
            excludedModes: [],
            preferredModes: [],
        )
        var previous = NaturalJourneyDialogueState(intent: previousIntent)
        previous[field: .origin] = .grounded(
            evidence: "depuis Auber",
            provenance: .deterministic,
        )
        previous[field: .destination] = .grounded(
            evidence: "Nation",
            provenance: .deterministic,
        )
        let correctedIntent = RouteIntent(
            scope: .journey,
            origin: .currentLocation,
            destinationQuery: "Bastille",
            requestedAt: ISO8601.parse("2026-08-26T18:00:00+02:00")!,
            datetimeRepresents: .departure,
            requiredModes: [],
            excludedModes: [],
            preferredModes: [],
            originWasExplicit: false,
        )
        let understanding = ReliableNaturalJourneyUnderstanding(
            localModel: EvidenceNaturalIntentParser(proposal: NaturalIntentProposal(
                intent: correctedIntent,
                destinationEvidence: "Bastille",
            )),
            remoteModel: nil,
            savedPlaces: { [] },
            serverFallbackAllowed: { false },
        )

        let transition = try await understanding.interpret(
            NaturalJourneyTurn(
                phrase: "Non, plutôt Bastille",
                locale: Locale(identifier: "fr_FR"),
                now: ISO8601.parse("2026-08-26T18:00:00+02:00")!,
            ),
            state: previous,
        )

        XCTAssertEqual(transition.state.intent.originPlace, .query("Auber"))
        XCTAssertEqual(transition.state.intent.destinationPlace, .query("Bastille"))
        XCTAssertEqual(transition.changedFields, [.destination])
        XCTAssertTrue(transition.conflicts.isEmpty)
    }

    func testImplicitModelFieldsCannotReplaceConfirmedContext() async throws {
        let previousIntent = RouteIntent(
            scope: .journey,
            originPlace: .query("Auber"),
            destinationPlace: .query("Nation"),
            requestedAt: ISO8601.parse("2026-08-26T18:00:00+02:00")!,
            datetimeRepresents: .departure,
            requiredModes: [],
            excludedModes: [],
            preferredModes: [],
        )
        var previous = NaturalJourneyDialogueState(intent: previousIntent)
        previous[field: .origin] = .confirmed(evidence: "depuis Auber")
        previous[field: .destination] = .confirmed(evidence: "Nation")
        let proposal = RouteIntent(
            scope: .journey,
            origin: .currentLocation,
            destinationQuery: nil,
            requestedAt: ISO8601.parse("2026-08-27T09:00:00+02:00")!,
            datetimeRepresents: .arrival,
            requiredModes: [],
            excludedModes: [],
            preferredModes: [],
            originWasExplicit: false,
        )
        let understanding = ReliableNaturalJourneyUnderstanding(
            localModel: EvidenceNaturalIntentParser(proposal: NaturalIntentProposal(
                intent: proposal,
                timeEvidence: "demain à 9 h",
            )),
            remoteModel: nil,
            savedPlaces: { [] },
            serverFallbackAllowed: { false },
        )

        let transition = try await understanding.interpret(
            NaturalJourneyTurn(
                phrase: "Demain à 9 h",
                locale: Locale(identifier: "fr_FR"),
                now: ISO8601.parse("2026-08-26T18:00:00+02:00")!,
            ),
            state: previous,
        )

        XCTAssertEqual(transition.state.intent.originPlace, .query("Auber"))
        XCTAssertEqual(transition.state.intent.destinationPlace, .query("Nation"))
        XCTAssertEqual(transition.state.intent.requestedAt, proposal.requestedAt)
        XCTAssertEqual(transition.changedFields, [.time])
    }
}

private struct EvidenceNaturalIntentParser: NaturalIntentParsing {
    let proposal: NaturalIntentProposal

    var availability: NaturalLanguageAvailability { .available }

    func proposeIntent(
        _: NaturalIntentModelRequest
    ) async throws(NaturalIntentParsingError) -> NaturalIntentProposal {
        proposal
    }
}

private actor NaturalJourneyPlaceSearchRecorder {
    private(set) var queries: [String] = []
    let result: SearchResult

    init(result: SearchResult) {
        self.result = result
    }

    func search(_ query: String) -> SearchResponse {
        queries.append(query)
        return SearchResponse(results: [result], addressSource: .ok)
    }
}

private actor NaturalJourneyPlanningRecorder: JourneyRepository {
    private(set) var requests: [JourneyRequest] = []

    func plan(_ request: JourneyRequest) async throws -> JourneyResult {
        requests.append(request)
        return .mapPreview
    }
}
