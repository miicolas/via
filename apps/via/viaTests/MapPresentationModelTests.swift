import XCTest
@testable import Via

final class MapPresentationModelTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "dev.via.map-presentation-tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    @MainActor
    func testOpeningPlannerRequestsLocationAndPrefillsOrigin() {
        let coordinate = GeoCoordinate(latitude: 48.85, longitude: 2.35)
        let model = makeModel(
            location: InMemoryLocationAdapter(
                authorization: .authorized,
                coordinate: coordinate
            )
        )

        model.send(.openPlanner)

        XCTAssertEqual(model.state.draft.origin, .currentLocation(coordinate))
        XCTAssertEqual(model.state.activeField, .destination)
        XCTAssertEqual(model.state.location, .located(coordinate))
    }

    @MainActor
    func testDeniedLocationKeepsDestinationFocused() {
        let model = makeModel(
            location: InMemoryLocationAdapter(
                authorization: .denied,
                coordinate: nil
            )
        )

        model.send(.openPlanner)

        XCTAssertNil(model.state.draft.origin)
        XCTAssertEqual(model.state.activeField, .destination)
        XCTAssertEqual(model.state.location, .failed(.denied))
    }

    @MainActor
    func testLateLocationDoesNotReplaceManuallySelectedOrigin() {
        let location = ControlledLocationAdapter()
        let model = makeModel(location: location)
        model.send(.openPlanner)
        model.send(.focus(.origin))
        let manualOrigin = address(id: "manual", name: "Gare de Lyon")
        model.send(.selectResult(manualOrigin))

        location.deliver(
            GeoCoordinate(latitude: 48.8566, longitude: 2.3522)
        )

        XCTAssertEqual(model.state.draft.origin, JourneyPlaceSelection(manualOrigin))
        XCTAssertEqual(model.state.activeField, .destination)
    }

    @MainActor
    func testExplicitLocationRequestCanRetryAfterTemporaryFailure() {
        let location = ControlledLocationAdapter()
        let model = makeModel(location: location)

        model.send(.requestLocation)
        XCTAssertEqual(location.requestCount, 1)
        XCTAssertEqual(model.state.location, .locating)

        location.fail()
        XCTAssertEqual(model.state.location, .failed(.authorized))

        model.send(.requestLocation)
        XCTAssertEqual(location.requestCount, 2)
        XCTAssertEqual(model.state.location, .locating)
    }

    @MainActor
    func testDefaultSearchDebounceWaitsBeforeCallingRepository() async {
        let search = SearchRepositoryRecorder(responses: [
            "nation": response(name: "Nation"),
        ])
        let model = MapPresentationModel(
            searchRepository: search,
            journeyRepository: InMemoryJourneyRepository(result: .mapPreview),
            naturalJourneyRepository: InMemoryNaturalJourneyRepository(),
            account: makeAccount(),
            locationAdapter: InMemoryLocationAdapter()
        )
        model.send(.openPlanner)
        model.send(.queryChanged(.destination, "nation"))

        try? await Task.sleep(for: .milliseconds(100))
        let earlyRequestCount = await search.requestCount
        XCTAssertEqual(earlyRequestCount, 0)

        await waitUntil { await search.requestCount == 1 }
        XCTAssertEqual(model.state.search.visibleResponse?.results.first?.name, "Nation")
    }

    @MainActor
    func testDestinationSelectionPlansFourAlternativesAndRecordsRecent() async {
        let search = SearchRepositoryRecorder(responses: ["défense": .mapPreview])
        let journeys = JourneyRepositoryRecorder(result: .mapPreview)
        let account = makeAccount()
        let model = makeModel(search: search, journeys: journeys, account: account)
        model.send(.openPlanner)
        model.send(.queryChanged(.destination, "défense"))
        await waitUntil {
            if case .loaded = model.state.search { return true }
            return false
        }

        let destination = SearchResponse.mapPreview.results[1]
        model.send(.selectResult(destination))
        await waitUntil { model.state.plannerStage == .results }

        let requests = await journeys.requests
        XCTAssertEqual(requests.count, 1)
        XCTAssertEqual(requests[0].limit, 4)
        XCTAssertNil(requests[0].requestedAt)
        XCTAssertNil(requests[0].datetimeRepresents)
        XCTAssertEqual(account.recentSearches.first?.id, destination.id)
        XCTAssertEqual(model.state.journeyResult?.journeys.count, 4)
    }

    @MainActor
    func testDestinationSelectionImmediatelyPlansFromKnownLocation() async {
        let coordinate = GeoCoordinate(latitude: 48.85, longitude: 2.35)
        let journeys = JourneyRepositoryRecorder(result: .mapPreview)
        let model = makeModel(
            journeys: journeys,
            location: InMemoryLocationAdapter(
                authorization: .authorized,
                coordinate: coordinate
            )
        )
        model.send(.openPlanner)
        model.send(.queryChanged(.origin, ""))
        model.send(.focus(.destination))

        model.send(.selectResult(address(id: "nation", name: "Nation")))
        await waitUntil { await journeys.requestCount == 1 }

        XCTAssertEqual(model.state.plannerStage, .results)
        XCTAssertEqual(model.state.draft.origin, .currentLocation(coordinate))
    }

    @MainActor
    func testSavedPlaceTapPlansJourneyWithoutRecordingARecent() async throws {
        let coordinate = GeoCoordinate(latitude: 48.85, longitude: 2.35)
        let journeys = JourneyRepositoryRecorder(result: .mapPreview)
        let account = makeAccount()
        let model = makeModel(
            journeys: journeys,
            account: account,
            location: InMemoryLocationAdapter(
                authorization: .authorized,
                coordinate: coordinate
            )
        )
        model.send(.preparePlanner)
        account.setPlace(address(id: "maison", name: "Maison"), role: .home)
        let home = try XCTUnwrap(account.place(for: .home))

        model.send(.selectSavedPlace(home))
        await waitUntil { await journeys.requestCount == 1 }

        XCTAssertEqual(model.state.plannerStage, .results)
        XCTAssertEqual(model.state.draft.origin, .currentLocation(coordinate))
        XCTAssertTrue(account.recentSearches.isEmpty)
    }

    @MainActor
    func testFavoriteWithCoordinatePlansJourneyAndWithoutFallsBackToSearch() async {
        let coordinate = GeoCoordinate(latitude: 48.85, longitude: 2.35)
        let journeys = JourneyRepositoryRecorder(result: .mapPreview)
        let model = makeModel(
            journeys: journeys,
            location: InMemoryLocationAdapter(
                authorization: .authorized,
                coordinate: coordinate
            )
        )
        model.send(.preparePlanner)

        let favorite = FavoriteStation(
            stationID: "chatou",
            name: "Chatou - Croissy",
            coordinate: GeoCoordinate(latitude: 48.88, longitude: 2.15),
            savedAt: .now,
            updatedAt: .now
        )
        model.send(.selectFavorite(favorite))
        await waitUntil { await journeys.requestCount == 1 }
        XCTAssertEqual(model.state.plannerStage, .results)

        let legacy = FavoriteStation(
            stationID: "vesinet",
            name: "Le Vésinet",
            savedAt: .now,
            updatedAt: .now
        )
        model.send(.selectFavorite(legacy))
        XCTAssertEqual(model.state.activeField, .destination)
        XCTAssertEqual(model.state.draft.query(for: .destination), "Le Vésinet")
    }

    @MainActor
    func testOpenStationShowsTheStationSheetFromHome() {
        let model = makeModel()
        model.send(.preparePlanner)

        let station = StationMapItem(
            id: StationID(rawValue: "chatou"),
            name: "Chatou - Croissy",
            coordinate: GeoCoordinate(latitude: 48.88, longitude: 2.15),
            routes: []
        )
        model.send(.openStation(station))

        XCTAssertEqual(model.state.selectedStation, station)
        XCTAssertEqual(model.state.selectedDetent, .medium)
    }

    @MainActor
    func testSubmittingSearchTextPlansNaturalJourneyAndFeedsSharedResults() async {
        let coordinate = JourneyResult.mapPreview.journeys[0].sections[0].from.coordinate
        let destination = SearchResponse.mapPreview.results[1]
        let result = naturalReady(destination: destination)
        let naturalJourneys = NaturalJourneyRepositoryRecorder(results: [result])
        let account = makeAccount()
        let model = makeModel(
            naturalJourneys: naturalJourneys,
            account: account,
            location: InMemoryLocationAdapter(
                authorization: .authorized,
                coordinate: coordinate
            )
        )
        model.send(.openPlanner)

        model.send(.submitNaturalJourney("Gare du Nord à 11 h"))
        await waitUntil { model.state.plannerStage == .results }

        let naturalRequests = await naturalJourneys.requests
        XCTAssertEqual(
            naturalRequests,
            [.submit(query: "Gare du Nord à 11 h", currentLocation: coordinate)]
        )
        XCTAssertEqual(model.state.naturalJourney.value, result)
        XCTAssertEqual(model.state.journeyResult, .mapPreview)
        XCTAssertEqual(model.state.selectedJourneyID, JourneyResult.mapPreview.journeys[0].id)
        XCTAssertEqual(model.state.displayedRequest?.origin, coordinate)
        XCTAssertEqual(model.state.displayedRequest?.destination.name, destination.name)
        XCTAssertEqual(model.state.displayedRequest?.datetimeRepresents, .arrival)
        XCTAssertEqual(account.recentSearches.first?.id, destination.id)
        XCTAssertNotNil(model.state.mapPresentation)
    }

    @MainActor
    func testLatestNaturalJourneyWinsWhenOlderResponseArrivesLate() async {
        let firstDestination = address(id: "first", name: "Premier")
        let secondDestination = address(id: "second", name: "Second")
        let naturalJourneys = DelayedNaturalJourneyRepository(responses: [
            "premier à 11 h": (naturalReady(destination: firstDestination), .milliseconds(80)),
            "second à 12 h": (naturalReady(destination: secondDestination), .milliseconds(5)),
        ])
        let model = makeModel(naturalJourneys: naturalJourneys)
        model.send(.openPlanner)

        model.send(.submitNaturalJourney("premier à 11 h"))
        await Task.yield()
        model.send(.submitNaturalJourney("second à 12 h"))

        await waitUntil { model.state.displayedRequest?.destination.name == "Second" }
        try? await Task.sleep(for: .milliseconds(100))

        XCTAssertEqual(model.state.naturalJourneyQuery, "second à 12 h")
        XCTAssertEqual(model.state.displayedRequest?.destination.name, "Second")
    }

    @MainActor
    func testClosingNaturalJourneyClearsAnswerAndMapRoute() async {
        let model = makeModel(
            naturalJourneys: InMemoryNaturalJourneyRepository(
                result: naturalReady(destination: SearchResponse.mapPreview.results[1])
            )
        )
        model.send(.openPlanner)
        model.send(.submitNaturalJourney("La Défense à 11 h"))
        await waitUntil { model.state.plannerStage == .results }

        model.send(.closeJourneys)

        XCTAssertEqual(model.state.naturalJourney, .idle)
        XCTAssertEqual(model.state.naturalJourneyQuery, "")
        XCTAssertNil(model.state.journeyResult)
        XCTAssertNil(model.state.mapPresentation)
        XCTAssertEqual(model.state.plannerStage, .editing(nil))
    }

    @MainActor
    func testBackDuringNaturalPlanningRejectsCancelledResponse() async {
        let destination = address(id: "slow-natural", name: "Lent")
        let naturalJourneys = DelayedNaturalJourneyRepository(responses: [
            "trajet lent": (naturalReady(destination: destination), .milliseconds(80)),
        ])
        let model = makeModel(naturalJourneys: naturalJourneys)
        model.send(.openPlanner)
        model.send(.submitNaturalJourney("trajet lent"))
        XCTAssertEqual(model.state.plannerStage, .planning)

        model.send(.backToForm)
        try? await Task.sleep(for: .milliseconds(100))

        XCTAssertEqual(model.state.activeField, .destination)
        XCTAssertEqual(model.state.naturalJourney, .idle)
        XCTAssertNil(model.state.journeyResult)
        XCTAssertNil(model.state.mapPresentation)
    }

    @MainActor
    func testNaturalClarificationKeepsQueryWithoutPublishingRoute() async {
        let clarification = NaturalJourneyResult.needsClarification(
            draft: NaturalJourneyDraft(
                intent: RouteIntent(
                    scope: .journey,
                    origin: .currentLocation,
                    destinationQuery: "Gare du Nord",
                    requestedAt: nil,
                    datetimeRepresents: .arrival,
                    requiredModes: [],
                    excludedModes: [],
                    preferredModes: []
                ),
                origin: nil,
                destination: nil
            ),
            fields: [NaturalJourneyClarification(
                target: .time,
                question: "Pour quand ?",
                candidates: []
            )]
        )
        let model = makeModel(
            naturalJourneys: InMemoryNaturalJourneyRepository(result: clarification)
        )
        model.send(.openPlanner)

        model.send(.submitNaturalJourney("Gare du Nord"))
        await waitUntil { model.state.plannerStage == .results }

        XCTAssertEqual(model.state.naturalJourneyQuery, "Gare du Nord")
        XCTAssertEqual(model.state.naturalJourney.value, clarification)
        XCTAssertNil(model.state.journeyResult)
        XCTAssertNil(model.state.mapPresentation)
    }

    @MainActor
    func testResolvingNaturalPlaceClarificationSubmitsExactDraftAndCandidate() async {
        let coordinate = GeoCoordinate(latitude: 48.85, longitude: 2.35)
        let destination = address(id: "nation", name: "Nation")
        let draft = NaturalJourneyDraft(
            intent: RouteIntent(
                scope: .journey,
                origin: .currentLocation,
                destinationQuery: "Nation",
                requestedAt: Date(timeIntervalSince1970: 1_787_000_400),
                datetimeRepresents: .departure,
                requiredModes: [],
                excludedModes: [],
                preferredModes: []
            ),
            origin: nil,
            destination: nil
        )
        let clarification = NaturalJourneyResult.needsClarification(
            draft: draft,
            fields: [.init(
                target: .destination,
                question: "Quelle destination ?",
                candidates: [destination]
            )]
        )
        let repository = NaturalJourneyRepositoryRecorder(results: [
            clarification,
            naturalReady(destination: destination),
        ])
        let model = makeModel(
            naturalJourneys: repository,
            location: InMemoryLocationAdapter(
                authorization: .authorized,
                coordinate: coordinate
            )
        )
        model.send(.openPlanner)
        model.send(.submitNaturalJourney("Nation à 11 h"))
        await waitUntil { model.state.naturalJourney.value == clarification }

        model.send(.resolveNaturalJourney(
            draft: draft,
            origin: nil,
            destination: destination,
            datetimeRepresents: nil
        ))
        await waitUntil { await repository.requests.count == 2 }

        let requests = await repository.requests
        XCTAssertEqual(
            requests[1],
            .resolve(
                draft: draft,
                currentLocation: coordinate,
                origin: nil,
                destination: destination,
                datetimeRepresents: nil
            )
        )
        XCTAssertEqual(model.state.journeyResult, .mapPreview)
    }

    @MainActor
    func testResolvingNaturalTimeClarificationSubmitsSelectedMeaning() async {
        let draft = NaturalJourneyDraft(
            intent: RouteIntent(
                scope: .journey,
                origin: .currentLocation,
                destinationQuery: "Nation",
                requestedAt: Date(timeIntervalSince1970: 1_787_000_400),
                datetimeRepresents: .ambiguous,
                requiredModes: [],
                excludedModes: [],
                preferredModes: []
            ),
            origin: nil,
            destination: address(id: "nation", name: "Nation")
        )
        let clarification = NaturalJourneyResult.needsClarification(
            draft: draft,
            fields: [.init(target: .time, question: "Départ ou arrivée ?", candidates: [])]
        )
        let repository = NaturalJourneyRepositoryRecorder(results: [
            clarification,
            .unsupported(message: "resolved", examples: []),
        ])
        let model = makeModel(naturalJourneys: repository)
        model.send(.openPlanner)
        model.send(.submitNaturalJourney("Nation à 11 h"))
        await waitUntil { model.state.naturalJourney.value == clarification }

        model.send(.resolveNaturalJourney(
            draft: draft,
            origin: nil,
            destination: nil,
            datetimeRepresents: .arrival
        ))
        await waitUntil { await repository.requests.count == 2 }

        let requests = await repository.requests
        guard case .resolve(_, _, _, _, let meaning) = requests[1] else {
            XCTFail("Expected a clarification resolution request")
            return
        }
        XCTAssertEqual(meaning, .arrival)
    }

    @MainActor
    func testNewNaturalSubmitCancelsAnOlderClarificationResolution() async {
        let destination = address(id: "resolved", name: "Réponse tardive")
        let replacement = address(id: "replacement", name: "Nouvelle réponse")
        let repository = NaturalResolutionRaceRepository(
            clarification: .needsClarification(
                draft: NaturalJourneyDraft(
                    intent: RouteIntent(
                        scope: .journey,
                        origin: .currentLocation,
                        destinationQuery: "Réponse tardive",
                        requestedAt: .now,
                        datetimeRepresents: .departure,
                        requiredModes: [],
                        excludedModes: [],
                        preferredModes: []
                    ),
                    origin: nil,
                    destination: nil
                ),
                fields: [.init(
                    target: .destination,
                    question: "Quelle destination ?",
                    candidates: [destination]
                )]
            ),
            resolved: naturalReady(destination: destination),
            replacement: naturalReady(destination: replacement)
        )
        let model = makeModel(naturalJourneys: repository)
        model.send(.openPlanner)
        model.send(.submitNaturalJourney("initial"))
        await waitUntil {
            guard case .loaded(.needsClarification) = model.state.naturalJourney else { return false }
            return true
        }
        guard case .needsClarification(let draft, _) = model.state.naturalJourney.value else {
            XCTFail("Expected clarification")
            return
        }

        model.send(.resolveNaturalJourney(
            draft: draft,
            origin: nil,
            destination: destination,
            datetimeRepresents: nil
        ))
        await Task.yield()
        model.send(.submitNaturalJourney("replacement"))

        await waitUntil { model.state.displayedRequest?.destination.name == "Nouvelle réponse" }
        try? await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(model.state.displayedRequest?.destination.name, "Nouvelle réponse")
    }

    @MainActor
    func testSelectingNaturalAlternativePromotesItOnMap() async {
        let model = makeModel(
            naturalJourneys: InMemoryNaturalJourneyRepository(
                result: naturalReady(destination: SearchResponse.mapPreview.results[1])
            )
        )
        model.send(.openPlanner)
        model.send(.submitNaturalJourney("La Défense à 11 h"))
        await waitUntil { model.state.plannerStage == .results }
        let alternative = JourneyResult.mapPreview.journeys[1]

        model.send(.selectJourney(alternative.id))

        XCTAssertEqual(model.state.selectedJourneyID, alternative.id)
        XCTAssertEqual(model.state.selectedJourney?.id, alternative.id)
        XCTAssertEqual(model.state.mapPresentation?.journey?.id, alternative.id)
        XCTAssertEqual(
            model.state.naturalJourneyPrimaryJourneyID,
            JourneyResult.mapPreview.journeys[0].id
        )
    }

    @MainActor
    func testRetryNaturalJourneyReusesLastRequest() async {
        let destination = SearchResponse.mapPreview.results[1]
        let naturalJourneys = SequencedNaturalJourneyRepository(outcomes: [
            .failure(.transport),
            .success(naturalReady(destination: destination)),
        ])
        let model = makeModel(naturalJourneys: naturalJourneys)
        model.send(.openPlanner)
        model.send(.submitNaturalJourney("La Défense à 11 h"))
        await waitUntil {
            if case .failed = model.state.naturalJourney { return true }
            return false
        }

        model.send(.retryNaturalJourney)
        await waitUntil { model.state.plannerStage == .results && model.state.journeyResult != nil }

        let requests = await naturalJourneys.requests
        XCTAssertEqual(requests.count, 2)
        XCTAssertEqual(requests[0], requests[1])
    }

    @MainActor
    func testLatestSearchWinsWhenAnOlderAdapterResponseArrivesLate() async {
        let first = response(name: "Premier")
        let second = response(name: "Second")
        let search = DelayedSearchRepository(responses: [
            "premier": (first, .milliseconds(80)),
            "second": (second, .milliseconds(5)),
        ])
        let model = makeModel(search: search)
        model.send(.openPlanner)
        model.send(.queryChanged(.destination, "premier"))
        await Task.yield()
        model.send(.queryChanged(.destination, "second"))

        await waitUntil {
            model.state.search.visibleResponse?.results.first?.name == "Second"
        }
        try? await Task.sleep(for: .milliseconds(100))

        XCTAssertEqual(model.state.search.visibleResponse?.results.first?.name, "Second")
    }

    @MainActor
    func testSearchFailureKeepsPreviousResponseVisible() async {
        let search = SearchRepositoryRecorder(
            responses: ["ok": response(name: "Conservé")],
            errors: ["erreur": .transport]
        )
        let model = makeModel(search: search)
        model.send(.openPlanner)
        model.send(.queryChanged(.destination, "ok"))
        await waitUntil {
            model.state.search.visibleResponse?.results.first?.name == "Conservé"
        }

        model.send(.queryChanged(.destination, "erreur"))
        await waitUntil {
            if case .failed = model.state.search { return true }
            return false
        }

        XCTAssertEqual(model.state.search.visibleResponse?.results.first?.name, "Conservé")
    }

    @MainActor
    func testUnavailableAddressSourceKeepsStationResults() async {
        let response = SearchResponse(
            results: [SearchResponse.mapPreview.results[0]],
            addressSource: .unavailable
        )
        let model = makeModel(
            search: SearchRepositoryRecorder(responses: ["nation": response])
        )
        model.send(.openPlanner)
        model.send(.queryChanged(.destination, "nation"))
        await waitUntil {
            model.state.search.visibleResponse?.addressSource == .unavailable
        }

        XCTAssertEqual(model.state.search.visibleResponse?.results.count, 1)
    }

    @MainActor
    func testJourneyFailureKeepsPreviousAlternativesAndMapRoute() async {
        let journeys = ConditionalJourneyRepository(
            results: ["Premier": .mapPreview],
            errors: ["Second": .transport]
        )
        let model = makeModel(journeys: journeys)
        model.send(.openPlanner)
        model.send(.selectResult(address(id: "first", name: "Premier")))
        await waitUntil { model.state.plannerStage == .results }
        let firstMapPresentation = model.state.mapPresentation

        model.send(.focus(.destination))
        model.send(.selectResult(address(id: "second", name: "Second")))
        await waitUntil {
            if case .failed = model.state.journeys { return true }
            return false
        }

        XCTAssertEqual(model.state.journeyResult, .mapPreview)
        XCTAssertEqual(model.state.displayedRequest?.destination.name, "Premier")
        XCTAssertEqual(model.state.mapPresentation, firstMapPresentation)
    }

    @MainActor
    func testNoRouteResponseRemainsLoadedForInlineEmptyState() async {
        let noRoute = JourneyResult(
            status: .noRoute,
            source: .theoretical,
            generatedAt: .now,
            journeys: []
        )
        let model = makeModel(
            journeys: InMemoryJourneyRepository(result: noRoute)
        )
        model.send(.openPlanner)
        model.send(.selectResult(address(id: "none", name: "Sans trajet")))
        await waitUntil { model.state.plannerStage == .results }

        XCTAssertEqual(model.state.journeyResult?.status, .noRoute)
        XCTAssertEqual(model.state.journeyResult?.journeys, [])
        XCTAssertNotNil(model.state.mapPresentation)
    }

    @MainActor
    func testUnavailableResponseRemainsLoadedForInlineFailureState() async {
        let unavailable = JourneyResult(
            status: .unavailable,
            source: nil,
            generatedAt: .now,
            journeys: []
        )
        let model = makeModel(
            journeys: InMemoryJourneyRepository(result: unavailable)
        )
        model.send(.openPlanner)
        model.send(.selectResult(address(id: "offline", name: "Indisponible")))
        await waitUntil { model.state.plannerStage == .results }

        XCTAssertEqual(model.state.journeyResult?.status, .unavailable)
        XCTAssertNotNil(model.state.mapPresentation)
    }

    @MainActor
    func testFewerThanFourAlternativesArePreserved() async {
        let single = JourneyResult(
            status: .ready,
            source: .realtime,
            generatedAt: .now,
            journeys: [JourneyResult.mapPreview.journeys[0]]
        )
        let model = makeModel(
            journeys: InMemoryJourneyRepository(result: single)
        )
        model.send(.openPlanner)
        model.send(.selectResult(address(id: "single", name: "Une proposition")))
        await waitUntil { model.state.plannerStage == .results }

        XCTAssertEqual(model.state.journeyResult?.journeys.count, 1)
    }

    @MainActor
    func testLatestJourneyWinsWhenPreviousPlanningIgnoresCancellation() async {
        let journeys = DelayedJourneyRepository()
        let model = makeModel(journeys: journeys)
        model.send(.openPlanner)
        model.send(.selectResult(address(id: "first", name: "Premier")))
        model.send(.focus(.destination))
        model.send(.selectResult(address(id: "second", name: "Second")))

        await waitUntil {
            model.state.displayedRequest?.destination.name == "Second"
        }
        try? await Task.sleep(for: .milliseconds(100))

        XCTAssertEqual(model.state.displayedRequest?.destination.name, "Second")
    }

    @MainActor
    func testBackDuringPlanningRejectsTheCancelledResponse() async {
        let model = makeModel(journeys: DelayedJourneyRepository())
        model.send(.openPlanner)
        model.send(.selectResult(address(id: "slow", name: "Premier")))
        XCTAssertEqual(model.state.plannerStage, .planning)

        model.send(.backToForm)
        try? await Task.sleep(for: .milliseconds(100))

        XCTAssertEqual(model.state.activeField, .destination)
        XCTAssertEqual(model.state.draft.destination?.name, "Premier")
        XCTAssertEqual(model.state.journeys, .idle)
        XCTAssertNil(model.state.mapPresentation)
    }

    @MainActor
    func testSwapSupportsCurrentLocationAsDestination() async {
        let journeys = JourneyRepositoryRecorder(result: .mapPreview)
        let model = makeModel(journeys: journeys)
        model.send(.openPlanner)
        let destination = address(id: "defense", name: "La Défense")
        model.send(.selectResult(destination))
        await waitUntil { model.state.plannerStage == .results }

        model.send(.swapPlaces)
        await waitUntil { await journeys.requestCount == 2 }

        guard let request = await journeys.requests.last else {
            XCTFail("La requête inversée est absente")
            return
        }
        XCTAssertEqual(request.origin, destination.coordinate)
        guard case .address(let id, let name, _, _) = request.destination else {
            XCTFail("Ma position doit être encodée comme destination locale")
            return
        }
        XCTAssertEqual(id, "current-location")
        XCTAssertEqual(name, "Ma position")
    }

    @MainActor
    func testBackPreservesDraftAndNewSearchOnlyClearsDestination() async {
        let model = makeModel()
        model.send(.openPlanner)
        model.send(.selectResult(address(id: "defense", name: "La Défense")))
        await waitUntil { model.state.plannerStage == .results }

        model.send(.backToForm)
        XCTAssertNotNil(model.state.draft.origin)
        XCTAssertNotNil(model.state.draft.destination)
        XCTAssertNotNil(model.state.journeyResult)
        XCTAssertEqual(model.state.activeField, .destination)

        model.send(.newSearch)
        XCTAssertNotNil(model.state.draft.origin)
        XCTAssertNil(model.state.draft.destination)
        XCTAssertEqual(model.state.journeys, .idle)
        XCTAssertNil(model.state.mapPresentation)
    }

    @MainActor
    func testFocusingEndpointDismissesResultsSheetWithoutClearingJourneyDraft() async {
        let model = makeModel()
        model.send(.openPlanner)
        model.send(.selectResult(address(id: "defense", name: "La Défense")))
        await waitUntil { model.state.plannerStage == .results }

        XCTAssertEqual(model.state.presentedSheet, .journeys)

        model.send(.focus(.origin))

        XCTAssertEqual(model.state.activeField, .origin)
        XCTAssertNil(model.state.presentedSheet)
        XCTAssertNotNil(model.state.draft.origin)
        XCTAssertNotNil(model.state.draft.destination)
        XCTAssertNotNil(model.state.journeyResult)
    }

    @MainActor
    func testPreparingInitialPlannerLoadsRecentSearchesWithoutActivatingSearch() {
        let account = makeAccount()
        let recentResult = address(id: "nation", name: "Nation")
        account.recordRecentSearch(recentResult)
        let model = makeModel(
            account: account,
            location: InMemoryLocationAdapter(authorization: .denied, coordinate: nil)
        )

        model.send(.preparePlanner)

        XCTAssertNil(model.state.activeField)
        guard case .idle = model.state.search else {
            XCTFail("The initial planner should expose the recent-search state")
            return
        }
        XCTAssertEqual(account.recentSearches.map(\.name), ["Nation"])
    }

    @MainActor
    func testRecentSearchFromInitialPlannerFillsDestination() {
        let account = makeAccount()
        let recentResult = address(id: "nation", name: "Nation")
        account.recordRecentSearch(recentResult)
        let model = makeModel(
            account: account,
            location: InMemoryLocationAdapter(authorization: .denied, coordinate: nil)
        )
        model.send(.preparePlanner)

        model.send(.selectRecent(RecentSearch(result: recentResult)))

        XCTAssertEqual(model.state.draft.destination?.name, "Nation")
        XCTAssertEqual(model.state.activeField, .destination)
    }

    @MainActor
    func testRecentSearchFromInitialPlannerImmediatelyPlansFromKnownLocation() async {
        let coordinate = GeoCoordinate(latitude: 48.85, longitude: 2.35)
        let recentResult = address(id: "nation", name: "Nation")
        let journeys = JourneyRepositoryRecorder(result: .mapPreview)
        let model = makeModel(
            journeys: journeys,
            location: InMemoryLocationAdapter(
                authorization: .authorized,
                coordinate: coordinate
            )
        )
        model.send(.preparePlanner)

        model.send(.selectRecent(RecentSearch(result: recentResult)))
        await waitUntil { await journeys.requestCount == 1 }

        XCTAssertEqual(model.state.plannerStage, .results)
        XCTAssertEqual(model.state.draft.origin, .currentLocation(coordinate))
        XCTAssertEqual(model.state.draft.destination, JourneyPlaceSelection(recentResult))
    }

    @MainActor
    func testSelectedRecentIsNotSearchedAgainWhenSearchableWritesItsName() {
        let recentResult = address(id: "nation", name: "Nation")
        let model = makeModel(
            location: InMemoryLocationAdapter(authorization: .denied, coordinate: nil)
        )
        model.send(.preparePlanner)
        model.send(.selectRecent(RecentSearch(result: recentResult)))

        model.send(.queryChanged(.destination, recentResult.name))

        XCTAssertEqual(model.state.draft.destination, JourneyPlaceSelection(recentResult))
        guard case .idle = model.state.search else {
            XCTFail("Selecting a recent address must not launch the same search again")
            return
        }
    }

    func testRecentIdentifiersSupportPrefixedAndLegacyValues() {
        let coordinate = GeoCoordinate(latitude: 48.85, longitude: 2.35)
        let prefixed = RecentSearch(
            id: "station:stop-id",
            kind: .station,
            name: "Nation",
            context: nil,
            coordinate: coordinate,
            savedAt: .now
        )
        let legacy = RecentSearch(
            id: "legacy-address",
            kind: .address,
            name: "Rue de Rivoli",
            context: "Paris",
            coordinate: coordinate,
            savedAt: .now
        )

        XCTAssertEqual(prefixed.resultIdentifier, "stop-id")
        XCTAssertEqual(legacy.resultIdentifier, "legacy-address")
        XCTAssertEqual(JourneyPlaceSelection(prefixed).id, "station:stop-id")
        XCTAssertEqual(JourneyPlaceSelection(legacy).id, "address:legacy-address")
    }

    @MainActor
    private func makeModel(
        search: any SearchRepository = InMemorySearchRepository(response: .mapPreview),
        journeys: any JourneyRepository = InMemoryJourneyRepository(result: .mapPreview),
        naturalJourneys: any NaturalJourneyRepository = InMemoryNaturalJourneyRepository(),
        account: AccountModel? = nil,
        location: any LocationAdapter = InMemoryLocationAdapter()
    ) -> MapPresentationModel {
        MapPresentationModel(
            searchRepository: search,
            journeyRepository: journeys,
            naturalJourneyRepository: naturalJourneys,
            account: account ?? makeAccount(),
            locationAdapter: location,
            searchDelay: .zero
        )
    }

    private func naturalReady(destination: SearchResult) -> NaturalJourneyResult {
        .ready(
            answer: "Arrivée à 10 h 57, dans les temps.",
            answerSource: .server,
            preferenceNotice: nil,
            interpretation: NaturalJourneyInterpretation(
                originLabel: "Ta position",
                destination: JourneyPlaceSelection(destination).journeyDestination,
                destinationResult: destination,
                requestedAt: Date(timeIntervalSince1970: 1_787_000_400),
                datetimeRepresents: .arrival,
                requiredModes: [],
                excludedModes: [],
                preferredModes: []
            ),
            journeys: .mapPreview
        )
    }

    @MainActor
    private func makeAccount() -> AccountModel {
        let account = AccountModel(
            store: AccountLocalStore(defaults: defaults),
            remote: InMemoryAccountRemote(),
            synchronizationEnabled: false
        )
        account.activate(userID: "test-user")
        return account
    }

    @MainActor
    private func waitUntil(
        _ predicate: @escaping @MainActor () async -> Bool,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        for _ in 0..<200 {
            if await predicate() { return }
            try? await Task.sleep(for: .milliseconds(5))
        }
        XCTFail("Condition was not met", file: file, line: line)
    }

    private func response(name: String) -> SearchResponse {
        SearchResponse(
            results: [address(id: name.lowercased(), name: name)],
            addressSource: .ok
        )
    }

    private func address(id: String, name: String) -> SearchResult {
        .address(AddressSearchResult(
            id: id,
            name: name,
            context: "Paris",
            coordinate: GeoCoordinate(latitude: 48.89, longitude: 2.24),
            distanceMeters: nil
        ))
    }
}

private actor SearchRepositoryRecorder: SearchRepository {
    let responses: [String: SearchResponse]
    let errors: [String: ViaError]
    private(set) var requests: [(String, GeoCoordinate?)] = []
    var requestCount: Int { requests.count }

    init(
        responses: [String: SearchResponse],
        errors: [String: ViaError] = [:]
    ) {
        self.responses = responses
        self.errors = errors
    }

    func search(query: String, near coordinate: GeoCoordinate?) async throws -> SearchResponse {
        requests.append((query, coordinate))
        if let error = errors[query] { throw error }
        return responses[query] ?? SearchResponse(results: [], addressSource: .ok)
    }
}

@MainActor
private final class ControlledLocationAdapter: LocationAdapter {
    var authorization: LocationAuthorization = .authorized
    var onEvent: (@MainActor (LocationAdapterEvent) -> Void)?
    private(set) var requestCount = 0

    func requestAuthorization() {}

    func requestLocation() {
        requestCount += 1
    }

    func deliver(_ coordinate: GeoCoordinate) {
        onEvent?(.located(coordinate))
    }

    func fail() {
        onEvent?(.failed(authorization))
    }
}

private actor DelayedSearchRepository: SearchRepository {
    let responses: [String: (SearchResponse, Duration)]

    init(responses: [String: (SearchResponse, Duration)]) {
        self.responses = responses
    }

    func search(query: String, near coordinate: GeoCoordinate?) async throws -> SearchResponse {
        guard let (response, delay) = responses[query] else {
            return SearchResponse(results: [], addressSource: .ok)
        }
        try? await Task.sleep(for: delay)
        return response
    }
}

private actor JourneyRepositoryRecorder: JourneyRepository {
    let result: JourneyResult
    private(set) var requests: [JourneyRequest] = []
    var requestCount: Int { requests.count }

    init(result: JourneyResult) {
        self.result = result
    }

    func plan(_ request: JourneyRequest) async throws -> JourneyResult {
        requests.append(request)
        return result
    }
}

private actor NaturalJourneyRepositoryRecorder: NaturalJourneyRepository {
    let results: [NaturalJourneyResult]
    private(set) var requests: [NaturalJourneyRequest] = []

    init(results: [NaturalJourneyResult]) {
        self.results = results
    }

    func submit(_ request: NaturalJourneyRequest) async throws -> NaturalJourneyResult {
        requests.append(request)
        return results[min(requests.count - 1, results.count - 1)]
    }
}

private actor DelayedNaturalJourneyRepository: NaturalJourneyRepository {
    let responses: [String: (NaturalJourneyResult, Duration)]

    init(responses: [String: (NaturalJourneyResult, Duration)]) {
        self.responses = responses
    }

    func submit(_ request: NaturalJourneyRequest) async throws -> NaturalJourneyResult {
        guard case .submit(let query, _) = request,
              let (result, delay) = responses[query] else {
            return .unsupported(message: "Demande inconnue", examples: [])
        }
        try? await Task.sleep(for: delay)
        return result
    }
}

private actor NaturalResolutionRaceRepository: NaturalJourneyRepository {
    let clarification: NaturalJourneyResult
    let resolved: NaturalJourneyResult
    let replacement: NaturalJourneyResult

    init(
        clarification: NaturalJourneyResult,
        resolved: NaturalJourneyResult,
        replacement: NaturalJourneyResult
    ) {
        self.clarification = clarification
        self.resolved = resolved
        self.replacement = replacement
    }

    func submit(_ request: NaturalJourneyRequest) async throws -> NaturalJourneyResult {
        switch request {
        case .submit(let query, _):
            if query == "replacement" {
                try? await Task.sleep(for: .milliseconds(5))
                return replacement
            }
            return clarification
        case .resolve:
            try? await Task.sleep(for: .milliseconds(80))
            return resolved
        }
    }
}

private actor SequencedNaturalJourneyRepository: NaturalJourneyRepository {
    let outcomes: [Result<NaturalJourneyResult, ViaError>]
    private(set) var requests: [NaturalJourneyRequest] = []

    init(outcomes: [Result<NaturalJourneyResult, ViaError>]) {
        self.outcomes = outcomes
    }

    func submit(_ request: NaturalJourneyRequest) async throws -> NaturalJourneyResult {
        requests.append(request)
        return try outcomes[min(requests.count - 1, outcomes.count - 1)].get()
    }
}

private actor DelayedJourneyRepository: JourneyRepository {
    func plan(_ request: JourneyRequest) async throws -> JourneyResult {
        let delay: Duration = request.destination.name == "Premier"
            ? .milliseconds(80)
            : .milliseconds(5)
        try? await Task.sleep(for: delay)
        return .mapPreview
    }
}

private actor ConditionalJourneyRepository: JourneyRepository {
    let results: [String: JourneyResult]
    let errors: [String: ViaError]

    init(
        results: [String: JourneyResult],
        errors: [String: ViaError]
    ) {
        self.results = results
        self.errors = errors
    }

    func plan(_ request: JourneyRequest) async throws -> JourneyResult {
        let name = request.destination.name
        if let error = errors[name] { throw error }
        return results[name] ?? JourneyResult(
            status: .noRoute,
            source: nil,
            generatedAt: .now,
            journeys: []
        )
    }
}
