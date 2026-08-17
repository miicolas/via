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
        account: AccountModel? = nil,
        location: any LocationAdapter = InMemoryLocationAdapter()
    ) -> MapPresentationModel {
        MapPresentationModel(
            searchRepository: search,
            journeyRepository: journeys,
            account: account ?? makeAccount(),
            locationAdapter: location,
            searchDelay: .zero
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
