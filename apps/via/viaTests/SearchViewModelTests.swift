import XCTest
@testable import Via

@MainActor
final class SearchViewModelTests: XCTestCase {
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
            coordinate: GeoCoordinate(latitude: 48.8566, longitude: 2.3522)
        ))
        let model = SearchViewModel(
            repository: InMemorySearchRepository.preview,
            journeyRepository: journeys,
            locationModel: location
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
            coordinate: .init(latitude: 48.8583, longitude: 2.3470)
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
            coordinate: .init(latitude: 48.8566, longitude: 2.3522)
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
            location: LocationModel(adapter: InMemoryLocationAdapter(coordinate: origin))
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

    func testSelectingAnotherJourneyReplacesMapPresentation() async {
        let model = makeModel(
            journeyRepository: JourneyRepositoryRecorder(result: .mapPreview),
            location: LocationModel(adapter: InMemoryLocationAdapter())
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

    func testNoRouteStateIsDisplayedWhenRepositoryReturnsNoRoute() async {
        let journeys = JourneyRepositoryRecorder(result: JourneyResult(
            status: .noRoute,
            source: nil,
            generatedAt: .now,
            journeys: []
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
            journeys: []
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
            synchronizationEnabled: false
        )
        account.activate(userID: "preferences-test")
        account.setPreferred(.metro, enabled: true)

        let base = JourneyRepositoryRecorder(result: .mapPreview)
        let repository = PreferenceAwareJourneyRepository(base: base, account: account)
        let model = makeModel(
            journeyRepository: repository,
            location: LocationModel(adapter: InMemoryLocationAdapter(authorization: .denied, coordinate: nil))
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

    private func makeModel(
        repository: any SearchRepository = InMemorySearchRepository.preview,
        journeyRepository: any JourneyRepository = InMemoryJourneyRepository(result: .mapPreview),
        location: LocationModel = LocationModel(adapter: InMemoryLocationAdapter())
    ) -> SearchViewModel {
        SearchViewModel(
            repository: repository,
            journeyRepository: journeyRepository,
            locationModel: location
        )
    }

    private func waitForLoadState(
        _ model: SearchViewModel,
        _ expected: SearchLoadState,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        for _ in 0..<160 {
            if model.loadState == expected { return }
            await Task.yield()
            try? await Task.sleep(for: .milliseconds(5))
        }
        XCTFail("Expected load state \(expected), got \(model.loadState)", file: file, line: line)
    }

    private func waitForStep(
        _ model: SearchViewModel,
        _ expected: SearchViewStep,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        for _ in 0..<160 {
            if model.step == expected { return }
            await Task.yield()
            try? await Task.sleep(for: .milliseconds(5))
        }
        XCTFail("Expected step \(expected), got \(model.step)", file: file, line: line)
    }

    private func waitUntil(
        _ predicate: @escaping @Sendable () async -> Bool,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        for _ in 0..<200 {
            if await predicate() { return }
            await Task.yield()
            try? await Task.sleep(for: .milliseconds(5))
        }
        XCTFail("Timed out waiting for condition", file: file, line: line)
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

private actor NeverFinishingSearchRepository: SearchRepository {
    func search(query: String, near coordinate: GeoCoordinate?) async throws -> SearchResponse {
        while !Task.isCancelled {
            try await Task.sleep(for: .seconds(1))
        }
        throw CancellationError()
    }
}

private actor DelayedSearchRepository: SearchRepository {
    private var recordedQueries: [String] = []

    func search(query: String, near coordinate: GeoCoordinate?) async throws -> SearchResponse {
        recordedQueries.append(query)
        if query == "old" {
            try await Task.sleep(for: .seconds(2))
            return .preview
        }
        return SearchResponse(results: [.previewAddress], addressSource: .ok)
    }

    func queries() -> [String] { recordedQueries }
}
