@testable import Via
import XCTest

@MainActor
final class NaturalJourneyDialogueTests: XCTestCase {
    func testFirstNaturalSearchOpeningDisclosesServerFallbackBeforeInput() {
        let onboarding = InMemoryNaturalJourneyOnboardingStore(hasSeenOnboarding: false)
        let (dialogue, _) = makeDialogue(
            naturalJourneyRepository: InMemoryNaturalJourneyRepository(),
            naturalLanguageAvailability: .available,
            naturalJourneyOnboardingStore: onboarding,
        )

        dialogue.open()

        XCTAssertTrue(dialogue.isPresented)
        XCTAssertEqual(dialogue.state, .onboarding)
        XCTAssertFalse(onboarding.hasSeenOnboarding)

        dialogue.showInput()

        XCTAssertEqual(dialogue.state, .input)
        XCTAssertTrue(onboarding.hasSeenOnboarding)
    }

    func testReopeningNaturalSearchReturnsToInput() {
        let onboarding = InMemoryNaturalJourneyOnboardingStore(hasSeenOnboarding: false)
        let (dialogue, _) = makeDialogue(
            naturalJourneyRepository: InMemoryNaturalJourneyRepository(),
            naturalLanguageAvailability: .available,
            naturalJourneyOnboardingStore: onboarding,
        )

        dialogue.open()
        dialogue.dismiss()
        dialogue.open()

        XCTAssertTrue(dialogue.isPresented)
        XCTAssertEqual(dialogue.state, .input)
    }

    func testIneligibleDeviceCannotOpenNaturalSearch() {
        let (dialogue, _) = makeDialogue(
            naturalJourneyRepository: InMemoryNaturalJourneyRepository(),
            naturalLanguageAvailability: .unavailable(.deviceNotEligible),
        )

        dialogue.open()

        XCTAssertFalse(dialogue.isPresented)
        XCTAssertEqual(dialogue.access, .hidden)
    }

    func testTemporarilyUnavailableModelOpensRecoveryExplanation() {
        let (dialogue, _) = makeDialogue(
            naturalJourneyRepository: InMemoryNaturalJourneyRepository(),
            naturalLanguageAvailability: .unavailable(.modelNotReady),
        )

        dialogue.open()

        XCTAssertTrue(dialogue.isPresented)
        XCTAssertEqual(dialogue.state, .availability(.modelNotReady))
    }

    func testNaturalSearchReadyResultUsesTheExistingJourneyPresentation() async {
        let recentStore = InMemoryRecentSearchStore()
        let interpretation = NaturalJourneyInterpretation(
            originLabel: "Ma position",
            destination: JourneyPlaceSelection(.previewStation).journeyDestination,
            destinationResult: .previewStation,
            requestedAt: ISO8601.parse("2026-08-21T08:00:00+02:00")!,
            datetimeRepresents: .arrival,
            requiredModes: [],
            excludedModes: [.rer],
            preferredModes: [],
        )
        let naturalRepository = NaturalJourneyRepositoryRecorder(
            result: .ready(interpretation: interpretation, journeys: .mapPreview),
        )
        let location = LocationModel(adapter: InMemoryLocationAdapter(
            coordinate: GeoCoordinate(latitude: 48.8566, longitude: 2.3522),
        ))
        _ = await location.requestCurrentLocation()
        let (dialogue, model) = makeDialogue(
            location: location,
            naturalJourneyRepository: naturalRepository,
            naturalLanguageAvailability: .available,
            naturalJourneyOnboardingStore: InMemoryNaturalJourneyOnboardingStore(
                hasSeenOnboarding: true,
            ),
            recentSearchStore: recentStore,
        )
        dialogue.query = "Châtelet demain avant 8 h, sans RER"

        dialogue.submit()
        await waitForStep(model, .results)

        XCTAssertEqual(model.selectedDestination, .previewStation)
        XCTAssertEqual(model.journeyResult, .mapPreview)
        XCTAssertEqual(model.selectedJourneyID, JourneyResult.mapPreview.journeys.first?.id)
        XCTAssertEqual(model.naturalJourneyCriteria?.requestedAt, interpretation.requestedAt)
        XCTAssertEqual(model.naturalJourneyCriteria?.datetimeRepresents, .arrival)
        XCTAssertEqual(model.naturalJourneyCriteria?.excludedModes, [.rer])
        XCTAssertFalse(dialogue.isPresented)
        guard case let .journey(outcomeJourneyID)? = dialogue.outcome else {
            return XCTFail("Expected a one-shot journey outcome for the shell")
        }
        XCTAssertEqual(outcomeJourneyID, JourneyResult.mapPreview.journeys.first?.id)
        dialogue.consumeOutcome()
        XCTAssertNil(dialogue.outcome)
        XCTAssertTrue(recentStore.load().isEmpty)
        let requests = await naturalRepository.requests
        XCTAssertEqual(requests, [.submit(
            query: "Châtelet demain avant 8 h, sans RER",
            currentLocation: GeoCoordinate(latitude: 48.8566, longitude: 2.3522),
        )])
    }

    func testNaturalSearchRecordsAnonymousFirstResultTiming() async {
        let interpretation = NaturalJourneyInterpretation(
            originLabel: "Ma position",
            destination: JourneyPlaceSelection(.previewStation).journeyDestination,
            destinationResult: .previewStation,
            requestedAt: ISO8601.parse("2026-08-21T08:00:00+02:00")!,
            datetimeRepresents: .arrival,
            requiredModes: [],
            excludedModes: [],
            preferredModes: [],
        )
        let metrics = NaturalJourneyMetricsRecorder()
        let (dialogue, model) = makeDialogue(
            naturalJourneyRepository: NaturalJourneyRepositoryRecorder(
                result: .ready(interpretation: interpretation, journeys: .mapPreview),
            ),
            naturalLanguageAvailability: .available,
            naturalJourneyOnboardingStore: InMemoryNaturalJourneyOnboardingStore(
                hasSeenOnboarding: true,
            ),
            naturalJourneyMetrics: metrics,
            now: { Date(timeIntervalSince1970: 42) },
        )
        dialogue.query = "Nation demain avant 8 h"

        dialogue.submit()
        await waitForStep(model, .results)

        XCTAssertEqual(metrics.searches, [NaturalJourneyMetric(
            outcome: .success,
            firstResultDurationMilliseconds: 0,
            correctionCount: 0,
        )])
    }

    func testIncorrectExecutionFeedbackIsASeparateAnonymousOutcome() async {
        let interpretation = NaturalJourneyInterpretation(
            originLabel: "Auber",
            destination: JourneyPlaceSelection(.previewStation).journeyDestination,
            destinationResult: .previewStation,
            requestedAt: ISO8601.parse("2026-08-21T08:00:00+02:00")!,
            datetimeRepresents: .arrival,
            requiredModes: [],
            excludedModes: [],
            preferredModes: [],
            processingPath: .serverModel,
        )
        let metrics = NaturalJourneyMetricsRecorder()
        let (dialogue, model) = makeDialogue(
            naturalJourneyRepository: NaturalJourneyRepositoryRecorder(
                result: .ready(interpretation: interpretation, journeys: .mapPreview),
            ),
            naturalLanguageAvailability: .available,
            naturalJourneyMetrics: metrics,
            now: { Date(timeIntervalSince1970: 42) },
        )
        dialogue.query = "Depuis Auber vers Nation"
        dialogue.submit()
        await waitForStep(model, .results)

        model.recordNaturalIncorrectExecution()

        XCTAssertEqual(metrics.searches.map(\.outcome), [.success, .incorrectExecution])
        XCTAssertEqual(metrics.searches.last?.processingPath, .serverModel)
    }

    func testNaturalNetworkFailureKeepsCriteriaAndPhraseForRetry() async {
        let requestedAt = ISO8601.parse("2026-08-21T08:00:00+02:00")!
        let interpretation = NaturalJourneyInterpretation(
            originLabel: "Ma position",
            destination: JourneyPlaceSelection(.previewStation).journeyDestination,
            destinationResult: .previewStation,
            requestedAt: requestedAt,
            datetimeRepresents: .arrival,
            requiredModes: [],
            excludedModes: [.rer],
            preferredModes: [],
        )
        let naturalRepository = NaturalJourneyRepositoryRecorder(
            result: .networkUnavailable(interpretation: interpretation),
        )
        let (dialogue, model) = makeDialogue(
            naturalJourneyRepository: naturalRepository,
            naturalLanguageAvailability: .available,
            naturalJourneyOnboardingStore: InMemoryNaturalJourneyOnboardingStore(
                hasSeenOnboarding: true,
            ),
        )
        dialogue.query = "Nation demain avant 8 h, sans RER"

        dialogue.submit()
        await waitForState(dialogue) {
            if case .failed = $0 { return true }
            return false
        }

        XCTAssertEqual(dialogue.query, "Nation demain avant 8 h, sans RER")
        XCTAssertEqual(model.naturalJourneyCriteria?.destinationResult, .previewStation)
        XCTAssertEqual(model.naturalJourneyCriteria?.requestedAt, requestedAt)
        XCTAssertEqual(model.naturalJourneyCriteria?.excludedModes, [.rer])
    }

    func testNaturalGeocodingFailureKeepsLocallyUnderstoodCriteria() async {
        let draft = NaturalJourneyDraft(
            intent: RouteIntent(
                scope: .journey,
                origin: .currentLocation,
                destinationQuery: "Nation",
                requestedAt: ISO8601.parse("2026-08-21T08:00:00+02:00")!,
                datetimeRepresents: .arrival,
                requiredModes: [],
                excludedModes: [.rer],
                preferredModes: [.bus],
                originWasExplicit: true,
            ),
            origin: nil,
            destination: nil,
        )
        let (dialogue, model) = makeDialogue(
            naturalJourneyRepository: NaturalJourneyRepositoryRecorder(
                result: .networkUnavailableDraft(draft: draft),
            ),
            naturalLanguageAvailability: .available,
            naturalJourneyOnboardingStore: InMemoryNaturalJourneyOnboardingStore(
                hasSeenOnboarding: true,
            ),
        )
        dialogue.query = "Nation demain avant 8 h, sans RER, plutôt en bus"

        dialogue.submit()
        await waitForState(dialogue) {
            if case .failed = $0 { return true }
            return false
        }

        XCTAssertNil(model.naturalJourneyCriteria)
        XCTAssertEqual(dialogue.unresolvedDraft, draft)
        XCTAssertEqual(dialogue.query, "Nation demain avant 8 h, sans RER, plutôt en bus")
    }

    func testSuccessfulNaturalSearchDoesNotKeepAReplayablePhrase() async {
        let interpretation = NaturalJourneyInterpretation(
            originLabel: "Ma position",
            destination: JourneyPlaceSelection(.previewStation).journeyDestination,
            destinationResult: .previewStation,
            requestedAt: ISO8601.parse("2026-08-21T08:00:00+02:00")!,
            datetimeRepresents: .arrival,
            requiredModes: [],
            excludedModes: [],
            preferredModes: [],
        )
        let repository = NaturalJourneyRepositoryRecorder(
            result: .ready(interpretation: interpretation, journeys: .mapPreview),
        )
        let (dialogue, model) = makeDialogue(
            naturalJourneyRepository: repository,
            naturalLanguageAvailability: .available,
            naturalJourneyOnboardingStore: InMemoryNaturalJourneyOnboardingStore(
                hasSeenOnboarding: true,
            ),
        )
        dialogue.query = "Nation demain avant 8 h"

        dialogue.submit()
        await waitForStep(model, .results)
        dialogue.retry()
        await Task.yield()

        XCTAssertEqual(dialogue.query, "")
        let requests = await repository.requests
        XCTAssertEqual(requests.count, 1)
    }

    func testLeavingForClassicSearchClearsTheNaturalPhraseAndRetryRequest() async {
        let repository = NaturalJourneyRepositoryRecorder(responses: [.failure(.transport)])
        let (dialogue, _) = makeDialogue(
            naturalJourneyRepository: repository,
            naturalLanguageAvailability: .available,
            naturalJourneyOnboardingStore: InMemoryNaturalJourneyOnboardingStore(
                hasSeenOnboarding: true,
            ),
        )
        dialogue.query = "Nation demain avant 8 h"
        dialogue.submit()
        await waitForState(dialogue) {
            if case .failed = $0 { return true }
            return false
        }

        dialogue.useClassicSearch()
        dialogue.retry()
        await Task.yield()

        XCTAssertEqual(dialogue.query, "")
        let requests = await repository.requests
        XCTAssertEqual(requests.count, 1)
    }

    func testNaturalPlaceClarificationStaysInTheSameSheetAndThenCompletes() async {
        let draft = NaturalJourneyDraft(
            intent: RouteIntent(
                scope: .journey,
                origin: .currentLocation,
                destinationQuery: "Nation",
                requestedAt: ISO8601.parse("2026-08-21T08:00:00+02:00")!,
                datetimeRepresents: .arrival,
                requiredModes: [],
                excludedModes: [],
                preferredModes: [],
            ),
            origin: nil,
            destination: nil,
        )
        let clarification = NaturalJourneyClarification(
            target: .destination,
            question: "Quel lieu veux-tu choisir ?",
            candidates: [.previewStation],
        )
        let interpretation = NaturalJourneyInterpretation(
            originLabel: "Ma position",
            destination: JourneyPlaceSelection(.previewStation).journeyDestination,
            destinationResult: .previewStation,
            requestedAt: draft.intent.requestedAt!,
            datetimeRepresents: .arrival,
            requiredModes: [],
            excludedModes: [],
            preferredModes: [],
        )
        let naturalRepository = NaturalJourneyRepositoryRecorder(results: [
            .needsClarification(draft: draft, fields: [clarification]),
            .ready(interpretation: interpretation, journeys: .mapPreview),
        ])
        let (dialogue, model) = makeDialogue(
            naturalJourneyRepository: naturalRepository,
            naturalLanguageAvailability: .available,
            naturalJourneyOnboardingStore: InMemoryNaturalJourneyOnboardingStore(
                hasSeenOnboarding: true,
            ),
        )
        dialogue.query = "Nation demain avant 8 h"

        dialogue.submit()
        await waitForState(dialogue) {
            if case .clarification = $0 { return true }
            return false
        }
        dialogue.resolve(
            draft: draft,
            with: .place(field: clarification, candidate: .previewStation),
        )
        await waitForStep(model, .results)

        XCTAssertFalse(dialogue.isPresented)
        let requests = await naturalRepository.requests
        XCTAssertEqual(requests.count, 2)
        guard case let .resolve(_, _, _, destination, _, _) = requests.last else {
            return XCTFail("Expected a clarification resolution")
        }
        XCTAssertEqual(destination, .previewStation)
    }

    func testFreeTextAfterAClarificationPatchesTheExistingDialogueState() async {
        let draft = NaturalJourneyDraft(
            intent: RouteIntent(
                scope: .journey,
                origin: .place(query: "Auber"),
                destinationQuery: "Nation",
                requestedAt: ISO8601.parse("2026-08-21T08:00:00+02:00")!,
                datetimeRepresents: .arrival,
                requiredModes: [],
                excludedModes: [],
                preferredModes: [],
            ),
            origin: .previewAddress,
            destination: nil,
        )
        let repository = NaturalJourneyRepositoryRecorder(results: [
            .needsDecision(
                draft: draft,
                decision: .interpretationConflict([.destination]),
            ),
            .unsupported(message: "fin", examples: []),
        ])
        let (dialogue, _) = makeDialogue(
            naturalJourneyRepository: repository,
            naturalLanguageAvailability: .available,
        )
        dialogue.query = "Depuis Auber vers Nation"
        dialogue.submit()
        await waitForState(dialogue) {
            if case .decision = $0 { return true }
            return false
        }

        dialogue.modifyQuery()
        dialogue.query = "Non, plutôt Bastille"
        dialogue.submit()
        await waitUntil { await repository.requests.count == 2 }

        let requests = await repository.requests
        guard case let .revise(query, revisedDraft, focusedField, _) = requests.last else {
            return XCTFail("La correction doit modifier la recherche en cours")
        }
        XCTAssertEqual(query, "Non, plutôt Bastille")
        XCTAssertEqual(revisedDraft, draft)
        XCTAssertNil(focusedField)
    }

    func testFreeTextReplyCarriesTheClarifiedOriginSlot() async {
        let draft = NaturalJourneyDraft(
            intent: RouteIntent(
                scope: .journey,
                origin: .currentLocation,
                destinationQuery: "Bonne Nouvelle",
                requestedAt: ISO8601.parse("2026-08-21T08:00:00+02:00")!,
                datetimeRepresents: .departure,
                requiredModes: [],
                excludedModes: [],
                preferredModes: [],
                originWasExplicit: false,
            ),
            origin: nil,
            destination: .previewStation,
        )
        let clarification = NaturalJourneyClarification(
            target: .origin,
            question: "D’où pars-tu ?",
            candidates: [],
        )
        let repository = NaturalJourneyRepositoryRecorder(results: [
            .needsClarification(draft: draft, fields: [clarification]),
            .unsupported(message: "fin", examples: []),
        ])
        let (dialogue, _) = makeDialogue(
            naturalJourneyRepository: repository,
            naturalLanguageAvailability: .available,
        )
        dialogue.query = "Bonne Nouvelle"
        dialogue.submit()
        await waitForState(dialogue) {
            if case .clarification = $0 { return true }
            return false
        }

        dialogue.modifyQuery()
        dialogue.query = "Chatou"
        dialogue.submit()
        await waitUntil { await repository.requests.count == 2 }

        let requests = await repository.requests
        guard case let .revise(query, revisedDraft, focusedField, _) = requests.last else {
            return XCTFail("La réponse doit réviser la demande en cours")
        }
        XCTAssertEqual(query, "Chatou")
        XCTAssertEqual(revisedDraft, draft)
        XCTAssertEqual(focusedField, .origin)
    }

    func testMissingHomeCanBeChosenAndSavedBeforeResuming() async {
        let draft = NaturalJourneyDraft(
            intent: RouteIntent(
                scope: .journey,
                origin: .place(query: "Auber"),
                destinationQuery: nil,
                requestedAt: ISO8601.parse("2026-08-21T08:00:00+02:00")!,
                datetimeRepresents: .departure,
                requiredModes: [],
                excludedModes: [],
                preferredModes: [],
            ),
            origin: .previewStation,
            destination: nil,
        )
        let repository = NaturalJourneyRepositoryRecorder(results: [
            .needsDecision(
                draft: draft,
                decision: .missingSavedPlace(target: .destination, kind: .home),
            ),
            .unsupported(message: "fin", examples: []),
        ])
        let account = AccountModel(
            remote: InMemoryAccountRemote(),
            synchronizationEnabled: false,
        )
        account.activate(userID: "natural-home-test")
        let (dialogue, _) = makeDialogue(
            account: account,
            naturalJourneyRepository: repository,
            naturalLanguageAvailability: .available,
        )
        dialogue.query = "rentrez chez moi depuis Auber"
        dialogue.submit()
        await waitForState(dialogue) {
            if case .decision = $0 { return true }
            return false
        }

        dialogue.chooseSavedPlace(
            draft: draft,
            target: .destination,
            kind: .home,
            savesPlace: true,
        )
        XCTAssertEqual(dialogue.savedPlaceSelectionRequest?.title, "Enregistrer Maison")
        dialogue.completeSavedPlaceSelection(.previewAddress)
        await waitUntil { await repository.requests.count == 2 }

        XCTAssertEqual(
            account.place(for: .home)?.searchResult,
            .address(AddressSearchResult(
                id: "preview:address:rivoli",
                name: "12 rue de Rivoli",
                context: "Paris",
                coordinate: .init(latitude: 48.8566, longitude: 2.3522),
                distanceMeters: nil,
            )),
        )
        let requests = await repository.requests
        guard case let .resolve(_, _, _, destination, _, _) = requests.last else {
            return XCTFail("Le lieu choisi doit reprendre le même trajet")
        }
        XCTAssertEqual(destination, .previewAddress)
    }

    func testEditingNaturalTimeReplansWithAllInterpretedConstraints() async {
        let firstTime = ISO8601.parse("2026-08-21T08:00:00+02:00")!
        let editedTime = ISO8601.parse("2026-08-21T18:00:00+02:00")!
        let coordinate = GeoCoordinate(latitude: 48.8566, longitude: 2.3522)
        let interpretation = NaturalJourneyInterpretation(
            originLabel: "Ma position",
            destination: JourneyPlaceSelection(.previewStation).journeyDestination,
            destinationResult: .previewStation,
            requestedAt: firstTime,
            datetimeRepresents: .arrival,
            requiredModes: [.metro],
            excludedModes: [.rer],
            preferredModes: [.bus],
        )
        let naturalRepository = NaturalJourneyRepositoryRecorder(
            result: .ready(interpretation: interpretation, journeys: .mapPreview),
        )
        let journeys = JourneyRepositoryRecorder(result: .mapPreview)
        let (dialogue, model) = makeDialogue(
            journeyRepository: journeys,
            location: LocationModel(adapter: InMemoryLocationAdapter(coordinate: coordinate)),
            naturalJourneyRepository: naturalRepository,
            naturalLanguageAvailability: .available,
            naturalJourneyOnboardingStore: InMemoryNaturalJourneyOnboardingStore(
                hasSeenOnboarding: true,
            ),
        )
        dialogue.query = "Nation avant 8 h sans RER"
        dialogue.submit()
        await waitForStep(model, .results)

        model.updateNaturalTime(editedTime, represents: .departure)
        await waitUntil { await journeys.requests().count == 1 }

        let request = await journeys.requests().first
        XCTAssertEqual(request?.requestedAt, editedTime)
        XCTAssertEqual(request?.datetimeRepresents, .departure)
        XCTAssertEqual(request?.requiredModes, [.metro])
        XCTAssertEqual(request?.excludedModes, [.rer])
        XCTAssertEqual(request?.preferredModes, [.bus])
    }

    func testNaturalSearchErrorPreservesThePhraseAndRetriesTheSameRequest() async {
        let naturalRepository = NaturalJourneyRepositoryRecorder(responses: [
            .failure(.transport),
            .success(.unsupported(message: "Demande hors périmètre", examples: [])),
        ])
        let (dialogue, _) = makeDialogue(
            naturalJourneyRepository: naturalRepository,
            naturalLanguageAvailability: .available,
            naturalJourneyOnboardingStore: InMemoryNaturalJourneyOnboardingStore(
                hasSeenOnboarding: true,
            ),
        )
        dialogue.query = "Nation demain avant 8 h"

        dialogue.submit()
        await waitForState(dialogue) {
            if case .failed = $0 { return true }
            return false
        }
        XCTAssertEqual(dialogue.query, "Nation demain avant 8 h")

        dialogue.retry()
        await waitForState(dialogue) {
            if case .unsupported = $0 { return true }
            return false
        }

        let requests = await naturalRepository.requests
        XCTAssertEqual(requests.count, 2)
        XCTAssertEqual(requests.first, requests.last)
    }

    func testParsingFailureReturnsToEditableInputWithoutRetryingTheSamePhrase() async {
        let naturalRepository = ParsingFailureNaturalJourneyRepository()
        let (dialogue, _) = makeDialogue(
            naturalJourneyRepository: naturalRepository,
            naturalLanguageAvailability: .available,
            naturalJourneyOnboardingStore: InMemoryNaturalJourneyOnboardingStore(
                hasSeenOnboarding: true,
            ),
        )
        dialogue.query = "Nation demain avant 8 h"

        dialogue.submit()
        await waitUntil { await naturalRepository.requestCount == 1 }
        await waitForState(dialogue) { $0 == .input }

        XCTAssertEqual(dialogue.query, "Nation demain avant 8 h")
        XCTAssertEqual(
            dialogue.inputErrorMessage,
            "Je n’ai pas compris. Vérifie les lieux et l’heure.",
        )

        dialogue.retry()
        await Task.yield()

        let requestCount = await naturalRepository.requestCount
        XCTAssertEqual(requestCount, 1)
    }

    func testSystemModelFailureShowsRecoveryGuidanceInsteadOfBlamingThePhrase() async {
        let naturalRepository = SystemModelFailureNaturalJourneyRepository()
        let (dialogue, _) = makeDialogue(
            naturalJourneyRepository: naturalRepository,
            naturalLanguageAvailability: .available,
            naturalJourneyOnboardingStore: InMemoryNaturalJourneyOnboardingStore(
                hasSeenOnboarding: true,
            ),
        )
        dialogue.query = "Nation demain avant 8 h"

        dialogue.submit()
        await waitUntil { await naturalRepository.requestCount == 1 }
        await waitForState(dialogue) {
            $0 == .availability(.systemUnavailable)
        }

        XCTAssertNil(dialogue.inputErrorMessage)
        var requestCount = await naturalRepository.requestCount
        XCTAssertEqual(requestCount, 1)

        dialogue.retryAvailability()
        await waitUntil { await naturalRepository.requestCount == 2 }
        requestCount = await naturalRepository.requestCount
        XCTAssertEqual(requestCount, 2)
    }

    func testNaturalModeDecisionSubmitsTheUsersChoice() async {
        let draft = NaturalJourneyDraft(
            intent: RouteIntent(
                scope: .journey,
                origin: .currentLocation,
                destinationQuery: "Nation",
                requestedAt: ISO8601.parse("2026-08-21T08:00:00+02:00")!,
                datetimeRepresents: .departure,
                requiredModes: [.metro],
                excludedModes: [.metro],
                preferredModes: [],
            ),
            origin: nil,
            destination: nil,
        )
        let naturalRepository = NaturalJourneyRepositoryRecorder(
            result: .unsupported(message: "stop", examples: []),
        )
        let (dialogue, _) = makeDialogue(
            naturalJourneyRepository: naturalRepository,
            naturalLanguageAvailability: .available,
        )

        dialogue.resolve(
            draft: draft,
            with: .modeConflict(mode: .metro, keeping: .excluded),
        )
        await waitForState(dialogue) {
            if case .unsupported = $0 { return true }
            return false
        }

        let requests = await naturalRepository.requests
        XCTAssertEqual(requests, [.resolveModeConflict(
            draft: draft,
            currentLocation: nil,
            mode: .metro,
            keeping: .excluded,
        )])
    }

    func testClassicTimeDoesNotOverrideNaturalJourneyCriteria() async {
        let naturalTime = ISO8601.parse("2026-08-22T09:00:00+02:00")!
        let classicTime = ISO8601.parse("2026-08-22T18:00:00+02:00")!
        let interpretation = NaturalJourneyInterpretation(
            originLabel: "Ma position",
            destination: JourneyPlaceSelection(.previewStation).journeyDestination,
            destinationResult: .previewStation,
            requestedAt: naturalTime,
            datetimeRepresents: .arrival,
            requiredModes: [],
            excludedModes: [],
            preferredModes: [],
        )
        let journeys = JourneyRepositoryRecorder(result: .mapPreview)
        let (dialogue, model) = makeDialogue(
            journeyRepository: journeys,
            naturalJourneyRepository: NaturalJourneyRepositoryRecorder(
                result: .ready(interpretation: interpretation, journeys: .mapPreview),
            ),
            naturalLanguageAvailability: .available,
            naturalJourneyOnboardingStore: InMemoryNaturalJourneyOnboardingStore(
                hasSeenOnboarding: true,
            ),
        )
        model.updateTime(classicTime, represents: .departure)
        dialogue.query = "Nation demain avant 9 h"

        dialogue.submit()
        await waitForStep(model, .results)
        model.updateNaturalTime(naturalTime, represents: .arrival)
        await waitUntil { await journeys.requests().count == 1 }

        let request = await journeys.requests().first
        XCTAssertEqual(request?.requestedAt, naturalTime)
        XCTAssertEqual(request?.datetimeRepresents, .arrival)
    }

    private func makeDialogue(
        repository: any SearchRepository = InMemorySearchRepository.preview,
        journeyRepository: any JourneyRepository = InMemoryJourneyRepository(result: .mapPreview),
        location: LocationModel = LocationModel(adapter: InMemoryLocationAdapter()),
        account: AccountModel? = nil,
        naturalJourneyRepository: (any NaturalJourneyRepository)? = nil,
        naturalLanguageAvailability: NaturalLanguageAvailability = .unavailable(.deviceNotEligible),
        naturalJourneyOnboardingStore: any NaturalJourneyOnboardingStoring = InMemoryNaturalJourneyOnboardingStore(),
        naturalJourneyMetrics: any NaturalJourneyMetricsRecording = NoOpNaturalJourneyMetrics(),
        now: @escaping @Sendable () -> Date = { .now },
        recentSearchStore: any RecentSearchStoring = InMemoryRecentSearchStore(),
    ) -> (dialogue: NaturalJourneyDialogue, model: SearchViewModel) {
        let model = SearchViewModel(
            repository: repository,
            journeyRepository: journeyRepository,
            locationModel: location,
            account: account,
            naturalLanguageAvailability: { naturalLanguageAvailability },
            naturalJourneyMetrics: naturalJourneyMetrics,
            now: now,
            filterStore: InMemorySearchFilterStore(),
            recentSearchStore: recentSearchStore,
        )
        let dialogue = NaturalJourneyDialogue(
            repository: naturalJourneyRepository,
            availability: { naturalLanguageAvailability },
            onboardingStore: naturalJourneyOnboardingStore,
            metrics: naturalJourneyMetrics,
            locationModel: location,
            account: account,
            planner: model,
            now: now,
        )
        return (dialogue, model)
    }

    private func waitForStep(
        _ model: SearchViewModel,
        _ expected: SearchViewStep,
        file: StaticString = #filePath,
        line: UInt = #line,
    ) async {
        for _ in 0 ..< 160 {
            if model.step == expected { return }
            await Task.yield()
            try? await Task.sleep(for: .milliseconds(5))
        }
        XCTFail("Expected step \(expected), got \(model.step)", file: file, line: line)
    }

    private func waitForState(
        _ dialogue: NaturalJourneyDialogue,
        matching predicate: (NaturalSearchState) -> Bool,
        file: StaticString = #filePath,
        line: UInt = #line,
    ) async {
        for _ in 0 ..< 160 {
            if predicate(dialogue.state) { return }
            await Task.yield()
            try? await Task.sleep(for: .milliseconds(5))
        }
        XCTFail("Unexpected natural search state \(dialogue.state)", file: file, line: line)
    }

    private func waitUntil(
        _ predicate: @escaping @Sendable () async -> Bool,
        file: StaticString = #filePath,
        line: UInt = #line,
    ) async {
        for _ in 0 ..< 200 {
            if await predicate() { return }
            await Task.yield()
            try? await Task.sleep(for: .milliseconds(5))
        }
        XCTFail("Timed out waiting for condition", file: file, line: line)
    }
}

private final class NaturalJourneyMetricsRecorder: NaturalJourneyMetricsRecording, @unchecked Sendable {
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

private actor NaturalJourneyRepositoryRecorder: NaturalJourneyRepository {
    private var responses: [Result<NaturalJourneyResult, ViaError>]
    private(set) var requests: [NaturalJourneyRequest] = []

    init(result: NaturalJourneyResult) {
        responses = [.success(result)]
    }

    init(results: [NaturalJourneyResult]) {
        responses = results.map(Result.success)
    }

    init(responses: [Result<NaturalJourneyResult, ViaError>]) {
        self.responses = responses
    }

    func submit(_ request: NaturalJourneyRequest) async throws -> NaturalJourneyResult {
        requests.append(request)
        let response = responses.count > 1 ? responses.removeFirst() : responses[0]
        return try response.get()
    }
}

private actor ParsingFailureNaturalJourneyRepository: NaturalJourneyRepository {
    private(set) var requestCount = 0

    func submit(_: NaturalJourneyRequest) async throws -> NaturalJourneyResult {
        requestCount += 1
        throw NaturalIntentParsingError.invalidResponse
    }
}

private actor SystemModelFailureNaturalJourneyRepository: NaturalJourneyRepository {
    private(set) var requestCount = 0

    func submit(_: NaturalJourneyRequest) async throws -> NaturalJourneyResult {
        requestCount += 1
        throw NaturalIntentParsingError.modelFailed
    }
}
