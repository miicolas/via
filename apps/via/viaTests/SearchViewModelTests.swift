@testable import Via
import XCTest

@MainActor
final class SearchViewModelTests: XCTestCase {
    func testFirstNaturalSearchOpeningDisclosesServerFallbackBeforeInput() {
        let onboarding = InMemoryNaturalJourneyOnboardingStore(hasSeenOnboarding: false)
        let model = makeModel(
            naturalJourneyRepository: InMemoryNaturalJourneyRepository(),
            naturalLanguageAvailability: .available,
            naturalJourneyOnboardingStore: onboarding,
        )

        model.openNaturalSearch()

        XCTAssertTrue(model.isNaturalSearchPresented)
        XCTAssertEqual(model.naturalSearchState, .onboarding)
        XCTAssertFalse(onboarding.hasSeenOnboarding)

        model.showNaturalSearchInput()

        XCTAssertEqual(model.naturalSearchState, .input)
        XCTAssertTrue(onboarding.hasSeenOnboarding)
    }

    func testReopeningNaturalSearchReturnsToInput() {
        let onboarding = InMemoryNaturalJourneyOnboardingStore(hasSeenOnboarding: false)
        let model = makeModel(
            naturalJourneyRepository: InMemoryNaturalJourneyRepository(),
            naturalLanguageAvailability: .available,
            naturalJourneyOnboardingStore: onboarding,
        )

        model.openNaturalSearch()
        model.dismissNaturalSearch()
        model.openNaturalSearch()

        XCTAssertTrue(model.isNaturalSearchPresented)
        XCTAssertEqual(model.naturalSearchState, .input)
    }

    func testIneligibleDeviceCannotOpenNaturalSearch() {
        let model = makeModel(
            naturalJourneyRepository: InMemoryNaturalJourneyRepository(),
            naturalLanguageAvailability: .unavailable(.deviceNotEligible),
        )

        model.openNaturalSearch()

        XCTAssertFalse(model.isNaturalSearchPresented)
        XCTAssertEqual(model.naturalLanguageAccess, .hidden)
    }

    func testTemporarilyUnavailableModelOpensRecoveryExplanation() {
        let model = makeModel(
            naturalJourneyRepository: InMemoryNaturalJourneyRepository(),
            naturalLanguageAvailability: .unavailable(.modelNotReady),
        )

        model.openNaturalSearch()

        XCTAssertTrue(model.isNaturalSearchPresented)
        XCTAssertEqual(model.naturalSearchState, .availability(.modelNotReady))
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
        let model = makeModel(
            location: location,
            naturalJourneyRepository: naturalRepository,
            naturalLanguageAvailability: .available,
            naturalJourneyOnboardingStore: InMemoryNaturalJourneyOnboardingStore(
                hasSeenOnboarding: true,
            ),
            recentSearchStore: recentStore,
        )
        model.naturalQuery = "Châtelet demain avant 8 h, sans RER"

        model.submitNaturalSearch()
        await waitForStep(model, .results)

        XCTAssertEqual(model.selectedDestination, .previewStation)
        XCTAssertEqual(model.journeyResult, .mapPreview)
        XCTAssertEqual(model.selectedJourneyID, JourneyResult.mapPreview.journeys.first?.id)
        XCTAssertEqual(model.naturalJourneyCriteria?.requestedAt, interpretation.requestedAt)
        XCTAssertEqual(model.naturalJourneyCriteria?.datetimeRepresents, .arrival)
        XCTAssertEqual(model.naturalJourneyCriteria?.excludedModes, [.rer])
        XCTAssertFalse(model.isNaturalSearchPresented)
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
        let model = makeModel(
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
        model.naturalQuery = "Nation demain avant 8 h"

        model.submitNaturalSearch()
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
        let model = makeModel(
            naturalJourneyRepository: NaturalJourneyRepositoryRecorder(
                result: .ready(interpretation: interpretation, journeys: .mapPreview),
            ),
            naturalLanguageAvailability: .available,
            naturalJourneyMetrics: metrics,
            now: { Date(timeIntervalSince1970: 42) },
        )
        model.naturalQuery = "Depuis Auber vers Nation"
        model.submitNaturalSearch()
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
        let model = makeModel(
            naturalJourneyRepository: naturalRepository,
            naturalLanguageAvailability: .available,
            naturalJourneyOnboardingStore: InMemoryNaturalJourneyOnboardingStore(
                hasSeenOnboarding: true,
            ),
        )
        model.naturalQuery = "Nation demain avant 8 h, sans RER"

        model.submitNaturalSearch()
        await waitForNaturalState(model) {
            if case .failed = $0 { return true }
            return false
        }

        XCTAssertEqual(model.naturalQuery, "Nation demain avant 8 h, sans RER")
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
        let model = makeModel(
            naturalJourneyRepository: NaturalJourneyRepositoryRecorder(
                result: .networkUnavailableDraft(draft: draft),
            ),
            naturalLanguageAvailability: .available,
            naturalJourneyOnboardingStore: InMemoryNaturalJourneyOnboardingStore(
                hasSeenOnboarding: true,
            ),
        )
        model.naturalQuery = "Nation demain avant 8 h, sans RER, plutôt en bus"

        model.submitNaturalSearch()
        await waitForNaturalState(model) {
            if case .failed = $0 { return true }
            return false
        }

        XCTAssertNil(model.naturalJourneyCriteria)
        XCTAssertEqual(model.naturalJourneyUnresolvedDraft, draft)
        XCTAssertEqual(model.naturalQuery, "Nation demain avant 8 h, sans RER, plutôt en bus")
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
        let model = makeModel(
            naturalJourneyRepository: repository,
            naturalLanguageAvailability: .available,
            naturalJourneyOnboardingStore: InMemoryNaturalJourneyOnboardingStore(
                hasSeenOnboarding: true,
            ),
        )
        model.naturalQuery = "Nation demain avant 8 h"

        model.submitNaturalSearch()
        await waitForStep(model, .results)
        model.retryNaturalSearch()
        await Task.yield()

        XCTAssertEqual(model.naturalQuery, "")
        let requests = await repository.requests
        XCTAssertEqual(requests.count, 1)
    }

    func testLeavingForClassicSearchClearsTheNaturalPhraseAndRetryRequest() async {
        let repository = NaturalJourneyRepositoryRecorder(responses: [.failure(.transport)])
        let model = makeModel(
            naturalJourneyRepository: repository,
            naturalLanguageAvailability: .available,
            naturalJourneyOnboardingStore: InMemoryNaturalJourneyOnboardingStore(
                hasSeenOnboarding: true,
            ),
        )
        model.naturalQuery = "Nation demain avant 8 h"
        model.submitNaturalSearch()
        await waitForNaturalState(model) {
            if case .failed = $0 { return true }
            return false
        }

        model.useClassicSearch()
        model.retryNaturalSearch()
        await Task.yield()

        XCTAssertEqual(model.naturalQuery, "")
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
        let model = makeModel(
            naturalJourneyRepository: naturalRepository,
            naturalLanguageAvailability: .available,
            naturalJourneyOnboardingStore: InMemoryNaturalJourneyOnboardingStore(
                hasSeenOnboarding: true,
            ),
        )
        model.naturalQuery = "Nation demain avant 8 h"

        model.submitNaturalSearch()
        await waitForNaturalState(model) {
            if case .clarification = $0 { return true }
            return false
        }
        model.resolveNaturalPlace(draft: draft, field: clarification, candidate: .previewStation)
        await waitForStep(model, .results)

        XCTAssertFalse(model.isNaturalSearchPresented)
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
        let model = makeModel(
            naturalJourneyRepository: repository,
            naturalLanguageAvailability: .available,
        )
        model.naturalQuery = "Depuis Auber vers Nation"
        model.submitNaturalSearch()
        await waitForNaturalState(model) {
            if case .decision = $0 { return true }
            return false
        }

        model.modifyNaturalQuery()
        model.naturalQuery = "Non, plutôt Bastille"
        model.submitNaturalSearch()
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
        let model = makeModel(
            naturalJourneyRepository: repository,
            naturalLanguageAvailability: .available,
        )
        model.naturalQuery = "Bonne Nouvelle"
        model.submitNaturalSearch()
        await waitForNaturalState(model) {
            if case .clarification = $0 { return true }
            return false
        }

        model.modifyNaturalQuery()
        model.naturalQuery = "Chatou"
        model.submitNaturalSearch()
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
        let model = makeModel(
            account: account,
            naturalJourneyRepository: repository,
            naturalLanguageAvailability: .available,
        )
        model.naturalQuery = "rentrez chez moi depuis Auber"
        model.submitNaturalSearch()
        await waitForNaturalState(model) {
            if case .decision = $0 { return true }
            return false
        }

        model.chooseNaturalSavedPlace(
            draft: draft,
            target: .destination,
            kind: .home,
            savesPlace: true,
        )
        XCTAssertEqual(model.naturalSavedPlaceSelectionRequest?.title, "Enregistrer Maison")
        model.completeNaturalSavedPlaceSelection(.previewAddress)
        await waitUntil { await repository.requests.count == 2 }

        XCTAssertEqual(account.place(for: .home)?.searchResult, .previewAddress)
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
        let model = makeModel(
            journeyRepository: journeys,
            location: LocationModel(adapter: InMemoryLocationAdapter(coordinate: coordinate)),
            naturalJourneyRepository: naturalRepository,
            naturalLanguageAvailability: .available,
            naturalJourneyOnboardingStore: InMemoryNaturalJourneyOnboardingStore(
                hasSeenOnboarding: true,
            ),
        )
        model.naturalQuery = "Nation avant 8 h sans RER"
        model.submitNaturalSearch()
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
        let model = makeModel(
            naturalJourneyRepository: naturalRepository,
            naturalLanguageAvailability: .available,
            naturalJourneyOnboardingStore: InMemoryNaturalJourneyOnboardingStore(
                hasSeenOnboarding: true,
            ),
        )
        model.naturalQuery = "Nation demain avant 8 h"

        model.submitNaturalSearch()
        await waitForNaturalState(model) {
            if case .failed = $0 { return true }
            return false
        }
        XCTAssertEqual(model.naturalQuery, "Nation demain avant 8 h")

        model.retryNaturalSearch()
        await waitForNaturalState(model) {
            if case .unsupported = $0 { return true }
            return false
        }

        let requests = await naturalRepository.requests
        XCTAssertEqual(requests.count, 2)
        XCTAssertEqual(requests.first, requests.last)
    }

    func testParsingFailureReturnsToEditableInputWithoutRetryingTheSamePhrase() async {
        let naturalRepository = ParsingFailureNaturalJourneyRepository()
        let model = makeModel(
            naturalJourneyRepository: naturalRepository,
            naturalLanguageAvailability: .available,
            naturalJourneyOnboardingStore: InMemoryNaturalJourneyOnboardingStore(
                hasSeenOnboarding: true,
            ),
        )
        model.naturalQuery = "Nation demain avant 8 h"

        model.submitNaturalSearch()
        await waitUntil { await naturalRepository.requestCount == 1 }
        await waitForNaturalState(model) { $0 == .input }

        XCTAssertEqual(model.naturalQuery, "Nation demain avant 8 h")
        XCTAssertEqual(
            model.naturalInputErrorMessage,
            "Je n’ai pas compris. Vérifie les lieux et l’heure.",
        )

        model.retryNaturalSearch()
        await Task.yield()

        let requestCount = await naturalRepository.requestCount
        XCTAssertEqual(requestCount, 1)
    }

    func testSystemModelFailureShowsRecoveryGuidanceInsteadOfBlamingThePhrase() async {
        let naturalRepository = SystemModelFailureNaturalJourneyRepository()
        let model = makeModel(
            naturalJourneyRepository: naturalRepository,
            naturalLanguageAvailability: .available,
            naturalJourneyOnboardingStore: InMemoryNaturalJourneyOnboardingStore(
                hasSeenOnboarding: true,
            ),
        )
        model.naturalQuery = "Nation demain avant 8 h"

        model.submitNaturalSearch()
        await waitUntil { await naturalRepository.requestCount == 1 }
        await waitForNaturalState(model) {
            $0 == .availability(.systemUnavailable)
        }

        XCTAssertNil(model.naturalInputErrorMessage)
        var requestCount = await naturalRepository.requestCount
        XCTAssertEqual(requestCount, 1)

        model.retryNaturalAvailability()
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
        let model = makeModel(
            naturalJourneyRepository: naturalRepository,
            naturalLanguageAvailability: .available,
        )

        model.resolveNaturalModeConflict(
            draft: draft,
            mode: .metro,
            keeping: .excluded,
        )
        await waitForNaturalState(model) {
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

    func testEnterBeforeSuggestionsArriveSelectsTheFirstResponse() async {
        let journeys = JourneyRepositoryRecorder(result: .mapPreview)
        let model = makeModel(journeyRepository: journeys)

        model.query = "cha"
        model.searchImmediately()
        await waitForStep(model, .results)

        XCTAssertEqual(model.selectedDestination, .previewStation)
        let requests = await journeys.requests()
        XCTAssertEqual(requests.count, 1)
    }

    func testEnterSelectsTheFirstLoadedDestinationAndPlansImmediately() async {
        let journeys = JourneyRepositoryRecorder(result: .mapPreview)
        let location = LocationModel(adapter: InMemoryLocationAdapter(
            coordinate: GeoCoordinate(latitude: 48.8566, longitude: 2.3522),
        ))
        let model = SearchViewModel(
            repository: InMemorySearchRepository.preview,
            journeyRepository: journeys,
            locationModel: location,
            recentSearchStore: InMemoryRecentSearchStore(),
        )

        model.updateQuery("cha")
        await waitForLoadState(model, .loaded)

        model.searchImmediately()
        await waitForStep(model, .results)

        XCTAssertEqual(model.selectedDestination, .previewStation)
        let requests = await journeys.requests()
        XCTAssertEqual(requests.count, 1)
        XCTAssertEqual(requests.first?.destination, .station(
            id: StationID(rawValue: "preview:chatelet"),
            name: "Châtelet",
            coordinate: .init(latitude: 48.8583, longitude: 2.3470),
        ))
    }

    func testSelectingASecondaryResultPlansThatResult() async {
        let journeys = JourneyRepositoryRecorder(result: .mapPreview)
        let model = makeModel(journeyRepository: journeys)

        model.updateQuery("cha")
        await waitForLoadState(model, .loaded)
        model.selectDestination(.previewAddress)
        await waitForStep(model, .results)

        XCTAssertEqual(model.selectedDestination, .previewAddress)
        let requests = await journeys.requests()
        XCTAssertEqual(requests.count, 1)
        XCTAssertEqual(requests.first?.destination, .address(
            id: "preview:address:rivoli",
            name: "12 rue de Rivoli",
            context: "Paris",
            coordinate: .init(latitude: 48.8566, longitude: 2.3522),
        ))
    }

    func testEmptySearchDoesNotPlanAJourney() async {
        let journeys = JourneyRepositoryRecorder(result: .mapPreview)
        let search = InMemorySearchRepository(response: SearchResponse(results: [], addressSource: .ok))
        let model = makeModel(repository: search, journeyRepository: journeys)

        model.updateQuery("unknown")
        await waitForLoadState(model, .empty)

        XCTAssertNil(model.selectedDestination)
        let requests = await journeys.requests()
        XCTAssertEqual(requests.count, 0)
    }

    func testSearchPublishesLoadingBeforeAResponseArrives() async {
        let search = NeverFinishingSearchRepository()
        let model = makeModel(repository: search)

        model.updateQuery("cha")
        await waitForLoadState(model, .loading)

        model.clearQuery()
        XCTAssertEqual(model.loadState, .idle)
    }

    func testDepartureSearchDebouncesAndLoadsResults() async {
        let model = makeModel(repository: InMemorySearchRepository.preview)

        model.updateDepartureQuery("cha")

        XCTAssertEqual(model.departureLoadState, .idle)
        await waitForDepartureLoadState(model, .loaded)

        XCTAssertEqual(model.departureResults, SearchResponse.preview.results)
    }

    func testBikeFilterRefreshesTheCurrentQueryAsVelibOnly() async {
        let repository = BikeFilterRecordingSearchRepository()
        let model = makeModel(repository: repository)

        model.updateQuery("hotel")
        await waitForLoadState(model, .loaded)
        model.setBikeStationsOnly(true)
        await waitUntil { await repository.filters.count == 2 }

        XCTAssertTrue(model.filters.bikeStationsOnly)
        let filters = await repository.filters
        XCTAssertEqual(filters, [false, true])
    }

    func testDepartureSearchCanBeEmpty() async {
        let repository = InMemorySearchRepository(
            response: SearchResponse(results: [], addressSource: .ok),
        )
        let model = makeModel(repository: repository)

        model.updateDepartureQuery("unknown")
        await waitForDepartureLoadState(model, .empty)

        XCTAssertTrue(model.departureResults.isEmpty)
    }

    func testFailedDepartureSearchCanRetry() async {
        let repository = QueuedSearchRepository(responses: [
            .failure(.transport),
            .success(.preview),
        ])
        let model = makeModel(repository: repository)

        model.updateDepartureQuery("cha")
        await waitForDepartureLoadState(model, .failed(.transport))

        model.retryDepartureSearch()
        await waitForDepartureLoadState(model, .loaded)

        XCTAssertEqual(model.departureResults, SearchResponse.preview.results)
        let queries = await repository.queries()
        XCTAssertEqual(queries, ["cha", "cha"])
    }

    func testObsoleteSearchRequestCannotOverwriteNewerResults() async {
        let search = DelayedSearchRepository()
        let model = makeModel(repository: search)

        model.updateQuery("old")
        await waitUntil { await search.queries().contains("old") }

        model.updateQuery("new")
        await waitForLoadState(model, .loaded)

        XCTAssertEqual(model.results, [.previewAddress])
        XCTAssertEqual(model.loadState, .loaded)
    }

    func testJourneySuccessShowsResultsAndKeepsRequestForNow() async {
        let journeys = JourneyRepositoryRecorder(result: .mapPreview)
        let origin = GeoCoordinate(latitude: 48.8566, longitude: 2.3522)
        let model = makeModel(
            journeyRepository: journeys,
            location: LocationModel(adapter: InMemoryLocationAdapter(coordinate: origin)),
        )

        model.selectDestination(.previewStation)
        await waitForStep(model, .results)

        guard let request = await journeys.requests().first else {
            return XCTFail("Expected one journey request")
        }
        XCTAssertEqual(request.origin, origin)
        XCTAssertEqual(request.limit, 4)
        XCTAssertNil(request.requestedAt)
        XCTAssertNil(request.datetimeRepresents)
        XCTAssertEqual(model.selectedJourneyID, JourneyResult.mapPreview.journeys.first?.id)
        XCTAssertFalse(model.mapPresentation?.segments.isEmpty ?? true)
    }

    func testExplicitTimeIsForwardedToJourneyRequestAndReset() async {
        let journeys = JourneyRepositoryRecorder(result: .mapPreview)
        let model = makeModel(journeyRepository: journeys)
        let requestedAt = ISO8601.parse("2026-08-22T08:30:00+02:00")!

        XCTAssertNil(model.requestedAt)
        model.updateTime(requestedAt, represents: .arrival)
        XCTAssertEqual(model.requestedAt, requestedAt)
        XCTAssertEqual(model.datetimeRepresents, .arrival)

        model.selectDestination(.previewStation)
        await waitForStep(model, .results)

        let request = await journeys.requests().first
        XCTAssertEqual(request?.requestedAt, requestedAt)
        XCTAssertEqual(request?.datetimeRepresents, .arrival)

        let updatedAt = ISO8601.parse("2026-08-22T10:15:00+02:00")!
        model.updateTime(updatedAt, represents: .departure)
        await waitUntil { await journeys.requests().count == 2 }

        let updatedRequest = await journeys.requests().last
        XCTAssertEqual(updatedRequest?.requestedAt, updatedAt)
        XCTAssertEqual(updatedRequest?.datetimeRepresents, .departure)

        model.resetSearch()

        XCTAssertNil(model.requestedAt)
        XCTAssertEqual(model.datetimeRepresents, .departure)
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
        let model = makeModel(
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
        model.naturalQuery = "Nation demain avant 9 h"

        model.submitNaturalSearch()
        await waitForStep(model, .results)
        model.updateNaturalTime(naturalTime, represents: .arrival)
        await waitUntil { await journeys.requests().count == 1 }

        let request = await journeys.requests().first
        XCTAssertEqual(request?.requestedAt, naturalTime)
        XCTAssertEqual(request?.datetimeRepresents, .arrival)
    }

    func testSelectingAnotherJourneyReplacesMapPresentation() async {
        let model = makeModel(
            journeyRepository: JourneyRepositoryRecorder(result: .mapPreview),
            location: LocationModel(adapter: InMemoryLocationAdapter()),
        )
        model.selectDestination(.previewStation)
        await waitForStep(model, .results)

        guard let alternate = JourneyResult.mapPreview.journeys.dropFirst().first else {
            return XCTFail("Expected an alternate journey")
        }
        model.selectJourney(alternate)

        XCTAssertEqual(model.selectedJourneyID, alternate.id)
        XCTAssertEqual(model.selectedJourney, alternate)
        XCTAssertEqual(model.mapPresentation, JourneyMapPresentation(journey: alternate))

        let sectionID = alternate.sections[0].id
        model.highlightJourneySection(sectionID)
        XCTAssertEqual(model.highlightedJourneySectionID, sectionID)

        model.highlightJourneySection(nil)
        XCTAssertNil(model.highlightedJourneySectionID)
    }

    func testScheduleRevisionSendsDepartureAndArrivalAsDistinctPlannerConstraints() async throws {
        let original = try XCTUnwrap(JourneyResult.mapPreview.journeys.first)
        let plannerJourney = original.identified(
            as: JourneyID(rawValue: "planner:revised-journey")
        )
        let result = JourneyResult(
            status: .ready,
            source: .realtime,
            generatedAt: .now,
            journeys: [plannerJourney]
        )
        let repository = JourneyRepositoryRecorder(result: result)
        let model = makeModel(journeyRepository: repository)
        let destination = JourneyPlaceSelection(.previewStation).journeyDestination
        let policy = JourneyPlanningPolicy(
            requiredModes: [.metro],
            excludedModes: [.bus],
            preferredModes: [.rer],
            requiresAccessibleStations: true,
            requiresOperationalElevators: true
        )
        let departure = Date(timeIntervalSince1970: 2_100_000_000)
        let arrival = departure.addingTimeInterval(3_600)

        let departureRevision = try await model.reviseJourneySchedule(
            original,
            destination: destination,
            policy: policy,
            requestedAt: departure,
            represents: .departure
        )
        let arrivalRevision = try await model.reviseJourneySchedule(
            departureRevision,
            destination: destination,
            policy: policy,
            requestedAt: arrival,
            represents: .arrival
        )

        let requests = await repository.requests()
        XCTAssertEqual(requests.map(\.requestedAt), [departure, arrival])
        XCTAssertEqual(requests.map(\.datetimeRepresents), [.departure, .arrival])
        XCTAssertEqual(requests.first?.requiredModes, [.metro])
        XCTAssertEqual(requests.first?.excludedModes, [.bus])
        XCTAssertEqual(requests.first?.preferredModes, [.rer])
        XCTAssertEqual(requests.first?.requiresAccessibleStations, true)
        XCTAssertEqual(requests.first?.requiresOperationalElevators, true)
        XCTAssertEqual(departureRevision.id, original.id)
        XCTAssertEqual(arrivalRevision.id, original.id)
        XCTAssertNotEqual(plannerJourney.id, original.id)
    }

    func testNoRouteStateIsDisplayedWhenRepositoryReturnsNoRoute() async {
        let journeys = JourneyRepositoryRecorder(result: JourneyResult(
            status: .noRoute,
            source: nil,
            generatedAt: .now,
            journeys: [],
        ))
        let model = makeModel(journeyRepository: journeys)

        model.selectDestination(.previewStation)
        await waitForStep(model, .noRoute)

        XCTAssertEqual(model.selectedDestination, .previewStation)
        XCTAssertNotNil(model.journeyResult)
    }

    func testJourneyErrorPreservesDestinationAndRetryUsesTheSameQuery() async {
        let journeys = JourneyRepositoryRecorder(responses: [
            .failure(.unavailable),
            .success(.mapPreview),
        ])
        let model = makeModel(journeyRepository: journeys)

        model.query = "rivoli"
        model.selectDestination(.previewAddress)
        await waitForStep(model, .failed(.unavailable))

        XCTAssertEqual(model.selectedDestination, .previewAddress)
        XCTAssertEqual(model.query, "rivoli")

        model.retryJourney()
        await waitForStep(model, .results)

        XCTAssertEqual(model.selectedDestination, .previewAddress)
        XCTAssertEqual(model.query, "rivoli")
        let requests = await journeys.requests()
        XCTAssertEqual(requests.count, 2)
        XCTAssertEqual(requests.last?.destination, JourneyPlaceSelection(.previewAddress).journeyDestination)
    }

    func testUnavailableJourneyStateIsDistinctFromNoRoute() async {
        let journeys = JourneyRepositoryRecorder(result: JourneyResult(
            status: .unavailable,
            source: nil,
            generatedAt: .now,
            journeys: [],
        ))
        let model = makeModel(journeyRepository: journeys)

        model.selectDestination(.previewStation)
        await waitForStep(model, .unavailable)
    }

    func testManualOriginIsUsedWithoutRequestingCurrentLocation() async {
        let journeys = JourneyRepositoryRecorder(result: .mapPreview)
        let location = LocationModel(adapter: InMemoryLocationAdapter(authorization: .denied, coordinate: nil))
        let model = makeModel(journeyRepository: journeys, location: location)

        model.selectDeparture(.manual(.previewAddress))
        model.selectDestination(.previewStation)
        await waitForStep(model, .results)

        let requests = await journeys.requests()
        XCTAssertEqual(requests.first?.origin, SearchResult.previewAddress.coordinate)
    }

    func testSavedHomeAndWorkOriginsUseTheirSavedCoordinates() async {
        let savedPlaces = [
            SavedPlace(result: .previewAddress, role: .home),
            SavedPlace(result: .previewStation, role: .work),
        ]

        for place in savedPlaces {
            let journeys = JourneyRepositoryRecorder(result: .mapPreview)
            let location = LocationModel(adapter: InMemoryLocationAdapter(authorization: .denied, coordinate: nil))
            let model = makeModel(journeyRepository: journeys, location: location)

            model.selectDeparture(.saved(place))
            model.selectDestination(.previewStation)
            await waitForStep(model, .results)

            let requests = await journeys.requests()
            XCTAssertEqual(requests.first?.origin, place.coordinate)
        }
    }

    func testSavedDestinationOriginsUseTheirSavedCoordinates() async {
        let defaultsName = "via.search-saved-destination-tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: defaultsName)!
        defer { defaults.removePersistentDomain(forName: defaultsName) }

        let account = AccountModel(
            store: AccountLocalStore(defaults: defaults),
            remote: InMemoryAccountRemote(),
            synchronizationEnabled: false,
        )
        account.activateAnonymous()
        account.saveDestination(
            .previewAddress,
            label: "Salle de sport",
            systemImage: "dumbbell.fill",
        )

        guard let destination = account.destinations.first else {
            return XCTFail("Expected a saved destination")
        }

        let journeys = JourneyRepositoryRecorder(result: .mapPreview)
        let model = makeModel(
            journeyRepository: journeys,
            location: LocationModel(adapter: InMemoryLocationAdapter(authorization: .denied, coordinate: nil)),
            account: account,
        )

        XCTAssertEqual(model.savedDestinations.map(\.label), ["Salle de sport"])

        model.selectDeparture(.savedDestination(destination))
        model.selectDestination(.previewStation)
        await waitForStep(model, .results)

        let requests = await journeys.requests()
        XCTAssertEqual(requests.first?.origin, destination.coordinate)
    }

    func testCurrentLocationFailureBlocksOnlyTheCurrentOrigin() async {
        let journeys = JourneyRepositoryRecorder(result: .mapPreview)
        let location = LocationModel(adapter: InMemoryLocationAdapter(authorization: .denied, coordinate: nil))
        let model = makeModel(journeyRepository: journeys, location: location)

        model.selectDestination(.previewStation)
        await waitForStep(model, .locationBlocked(.denied))

        let requests = await journeys.requests()
        XCTAssertTrue(requests.isEmpty)
    }

    func testTransportPreferencesAreAppliedSilentlyByTheRepository() async {
        let account = AccountModel(
            remote: InMemoryAccountRemote(),
            synchronizationEnabled: false,
        )
        account.activate(userID: "preferences-test")
        account.setPreferred(.metro, enabled: true)

        let base = JourneyRepositoryRecorder(result: .mapPreview)
        let repository = PreferenceAwareJourneyRepository(base: base, account: account)
        let model = makeModel(
            journeyRepository: repository,
            location: LocationModel(adapter: InMemoryLocationAdapter(authorization: .denied, coordinate: nil)),
        )

        model.selectDeparture(.manual(.previewAddress))
        model.selectDestination(.previewStation)
        await waitForStep(model, .results)

        let requests = await base.requests()
        XCTAssertEqual(requests.first?.preferredModes, [.metro])
        XCTAssertTrue(requests.first?.requiredModes.isEmpty == true)
    }

    func testSavedHomeAndWorkAreAvailableOnlyWhenConfigured() {
        let home = SavedPlace(result: .previewAddress, role: .home)
        let work = SavedPlace(result: .previewStation, role: .work)

        XCTAssertEqual(home.role.displayTitle, "Maison")
        XCTAssertEqual(work.role.displayTitle, "Travail")
        XCTAssertTrue([home].contains { $0.role == .home })
        XCTAssertFalse([home].contains { $0.role == .work })
    }

    func testEditDestinationReturnsToTheFieldAndClearsOnlyTheDestination() async {
        let model = makeModel(journeyRepository: JourneyRepositoryRecorder(result: .mapPreview))

        model.selectDestination(.previewStation)
        await waitForStep(model, .results)
        model.editDestination()

        XCTAssertEqual(model.step, .destination)
        XCTAssertNil(model.selectedDestination)
        XCTAssertNil(model.journeyResult)
        XCTAssertEqual(model.selectedDeparture, .currentLocation)
    }

    func testResetSearchReturnsTheWholeSurfaceToItsInitialState() async {
        let model = makeModel(journeyRepository: JourneyRepositoryRecorder(result: .mapPreview))

        model.selectDeparture(.manual(.previewAddress))
        model.query = "châtelet"
        model.selectDestination(.previewStation)
        await waitForStep(model, .results)

        XCTAssertTrue(model.canResetSearch)

        model.resetSearch()

        XCTAssertEqual(model.step, .destination)
        XCTAssertEqual(model.query, "")
        XCTAssertEqual(model.results, [])
        XCTAssertEqual(model.loadState, .idle)
        XCTAssertEqual(model.accessibilitySource.status, .unavailable)
        XCTAssertNil(model.selectedDestination)
        XCTAssertEqual(model.selectedDeparture, .currentLocation)
        XCTAssertNil(model.journeyResult)
        XCTAssertNil(model.mapPresentation)
        XCTAssertNil(model.highlightedJourneySectionID)
        XCTAssertNil(model.naturalJourneyCriteria)
        XCTAssertFalse(model.canResetSearch)
    }

    func testClassicDestinationIsRecordedLocallyAndControlsRecentsVisibility() async {
        let store = InMemoryRecentSearchStore()
        let savedAt = Date(timeIntervalSince1970: 100)
        let model = makeModel(
            journeyRepository: JourneyRepositoryRecorder(result: .mapPreview),
            now: { savedAt },
            recentSearchStore: store,
        )

        model.selectDestination(.previewStation)
        await waitForStep(model, .results)
        model.resetSearch()

        XCTAssertEqual(model.recentSearches.map(\.id), [SearchResult.previewStation.id])
        XCTAssertEqual(model.recentSearches.first?.savedAt, savedAt)
        XCTAssertTrue(model.showsRecentSearches)

        model.query = "na"
        XCTAssertFalse(model.showsRecentSearches)
        model.query = ""
        model.removeRecentSearch(id: SearchResult.previewStation.id)
        XCTAssertTrue(model.recentSearches.isEmpty)
        XCTAssertFalse(model.showsRecentSearches)
    }

    func testRecentSearchesAreAvailableWhenChoosingAnotherDeparture() {
        let recent = RecentSearch(result: .previewAddress, savedAt: .now)
        let model = makeModel(
            recentSearchStore: InMemoryRecentSearchStore(searches: [recent]),
        )

        XCTAssertTrue(model.showsRecentDepartureSearches)

        model.updateDepartureQuery("cha")

        XCTAssertFalse(model.showsRecentDepartureSearches)

        model.clearDepartureSearch()

        XCTAssertTrue(model.showsRecentDepartureSearches)
        XCTAssertEqual(model.recentSearches, [recent])
    }

    func testVelibFilterHidesNonBikeRecentDestinations() {
        let bikeResult = BikeStation(
            id: "1",
            stationCode: "04001",
            name: "Hôtel de Ville",
            coordinate: GeoCoordinate(latitude: 48.8569, longitude: 2.3522),
            capacity: 35,
            availability: nil
        ).searchResult
        let store = InMemoryRecentSearchStore(searches: [
            RecentSearch(result: .previewStation, savedAt: Date(timeIntervalSince1970: 1)),
            RecentSearch(result: bikeResult, savedAt: Date(timeIntervalSince1970: 2)),
        ])
        let model = makeModel(recentSearchStore: store)

        model.setBikeStationsOnly(true)

        XCTAssertEqual(model.visibleRecentSearches.map(\.id), [bikeResult.id])
        XCTAssertTrue(model.showsRecentSearches)
    }

    func testSelectingARecentDestinationReordersItAndPlansTheJourney() async {
        let store = InMemoryRecentSearchStore()
        let recent = RecentSearch(result: .previewAddress, savedAt: .distantPast)
        _ = store.upsert(recent)
        let journeys = JourneyRepositoryRecorder(result: .mapPreview)
        let model = makeModel(
            journeyRepository: journeys,
            now: { Date(timeIntervalSince1970: 100) },
            recentSearchStore: store,
        )

        model.selectRecentSearch(recent)
        await waitForStep(model, .results)

        XCTAssertEqual(model.selectedDestination, .previewAddress)
        XCTAssertEqual(model.recentSearches.first?.id, recent.id)
        XCTAssertEqual(model.recentSearches.first?.savedAt, Date(timeIntervalSince1970: 100))
        let requests = await journeys.requests()
        XCTAssertEqual(requests.count, 1)

        model.clearRecentSearches()
        XCTAssertTrue(model.recentSearches.isEmpty)
    }

    private func makeModel(
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
    ) -> SearchViewModel {
        SearchViewModel(
            repository: repository,
            journeyRepository: journeyRepository,
            locationModel: location,
            account: account,
            naturalJourneyRepository: naturalJourneyRepository,
            naturalLanguageAvailability: { naturalLanguageAvailability },
            naturalJourneyOnboardingStore: naturalJourneyOnboardingStore,
            naturalJourneyMetrics: naturalJourneyMetrics,
            now: now,
            recentSearchStore: recentSearchStore,
        )
    }

    private func waitForLoadState(
        _ model: SearchViewModel,
        _ expected: SearchLoadState,
        file: StaticString = #filePath,
        line: UInt = #line,
    ) async {
        for _ in 0 ..< 160 {
            if model.loadState == expected { return }
            await Task.yield()
            try? await Task.sleep(for: .milliseconds(5))
        }
        XCTFail("Expected load state \(expected), got \(model.loadState)", file: file, line: line)
    }

    private func waitForDepartureLoadState(
        _ model: SearchViewModel,
        _ expected: SearchLoadState,
        file: StaticString = #filePath,
        line: UInt = #line,
    ) async {
        for _ in 0 ..< 160 {
            if model.departureLoadState == expected { return }
            await Task.yield()
            try? await Task.sleep(for: .milliseconds(5))
        }
        XCTFail(
            "Expected departure load state \(expected), got \(model.departureLoadState)",
            file: file,
            line: line,
        )
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

    private func waitForNaturalState(
        _ model: SearchViewModel,
        matching predicate: (NaturalSearchState) -> Bool,
        file: StaticString = #filePath,
        line: UInt = #line,
    ) async {
        for _ in 0 ..< 160 {
            if predicate(model.naturalSearchState) { return }
            await Task.yield()
            try? await Task.sleep(for: .milliseconds(5))
        }
        XCTFail("Unexpected natural search state \(model.naturalSearchState)", file: file, line: line)
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

private actor JourneyRepositoryRecorder: JourneyRepository {
    private var queuedResponses: [Result<JourneyResult, ViaError>]
    private(set) var recordedRequests: [JourneyRequest] = []

    init(result: JourneyResult) {
        queuedResponses = [.success(result)]
    }

    init(responses: [Result<JourneyResult, ViaError>]) {
        queuedResponses = responses
    }

    func plan(_ request: JourneyRequest) async throws -> JourneyResult {
        recordedRequests.append(request)
        let response = queuedResponses.count > 1 ? queuedResponses.removeFirst() : queuedResponses[0]
        return try response.get()
    }

    func requests() -> [JourneyRequest] { recordedRequests }
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

private actor NeverFinishingSearchRepository: SearchRepository {
    func search(
        query _: String,
        near _: GeoCoordinate?,
        bikeStationsOnly _: Bool
    ) async throws -> SearchResponse {
        while !Task.isCancelled {
            try await Task.sleep(for: .seconds(1))
        }
        throw CancellationError()
    }
}

private actor DelayedSearchRepository: SearchRepository {
    private var recordedQueries: [String] = []

    func search(
        query: String,
        near _: GeoCoordinate?,
        bikeStationsOnly _: Bool
    ) async throws -> SearchResponse {
        recordedQueries.append(query)
        if query == "old" {
            try await Task.sleep(for: .seconds(2))
            return .preview
        }
        return SearchResponse(results: [.previewAddress], addressSource: .ok)
    }

    func queries() -> [String] { recordedQueries }
}

private actor QueuedSearchRepository: SearchRepository {
    private var responses: [Result<SearchResponse, ViaError>]
    private var recordedQueries: [String] = []

    init(responses: [Result<SearchResponse, ViaError>]) {
        self.responses = responses
    }

    func search(
        query: String,
        near _: GeoCoordinate?,
        bikeStationsOnly _: Bool
    ) async throws -> SearchResponse {
        recordedQueries.append(query)
        let response = responses.count > 1 ? responses.removeFirst() : responses[0]
        return try response.get()
    }

    func queries() -> [String] { recordedQueries }
}

private actor BikeFilterRecordingSearchRepository: SearchRepository {
    private(set) var filters: [Bool] = []

    func search(
        query _: String,
        near _: GeoCoordinate?,
        bikeStationsOnly: Bool
    ) async throws -> SearchResponse {
        filters.append(bikeStationsOnly)
        return .preview
    }
}
