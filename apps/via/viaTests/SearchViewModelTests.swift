@testable import Via
import XCTest

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

    func testExpiredCurrentLocationRefreshesPlanningAndLeavesProximityWithoutAStaleCoordinate() async throws {
        let clock = SearchTestClock(Date(timeIntervalSince1970: 4_000))
        let first = GeoCoordinate(latitude: 48.8566, longitude: 2.3522)
        let second = GeoCoordinate(latitude: 48.8666, longitude: 2.3622)
        let adapter = SearchRecordingLocationAdapter(
            authorization: .authorized,
            coordinate: first,
            recordedAt: clock.now()
        )
        let location = LocationModel(adapter: adapter, now: clock.now)
        let journeys = JourneyRepositoryRecorder(result: .mapPreview)
        let model = makeModel(journeyRepository: journeys, location: location)

        let initial = await location.requestCurrentLocation()
        XCTAssertEqual(initial, first)
        XCTAssertEqual(adapter.locationRequestCount, 1)

        clock.advance(by: 61)
        XCTAssertNil(location.coordinate)
        _ = try await model.searchPlaces(query: "nation")
        XCTAssertEqual(adapter.locationRequestCount, 1)

        adapter.coordinate = second
        adapter.recordedAt = clock.now()
        model.selectDestination(.previewStation)
        await waitForStep(model, .results)

        let requests = await journeys.requests()
        XCTAssertEqual(requests.first?.origin, second)
        XCTAssertEqual(adapter.locationRequestCount, 2)
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

        XCTAssertEqual(
            model.selectedDestination,
            .address(AddressSearchResult(
                id: "preview:address:rivoli",
                name: "12 rue de Rivoli",
                context: "Paris",
                coordinate: .init(latitude: 48.8566, longitude: 2.3522),
                distanceMeters: nil,
            )),
        )
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
        now: @escaping @Sendable () -> Date = { .now },
        filterStore: any SearchFilterStoring = InMemorySearchFilterStore(),
        recentSearchStore: any RecentSearchStoring = InMemoryRecentSearchStore(),
    ) -> SearchViewModel {
        SearchViewModel(
            repository: repository,
            journeyRepository: journeyRepository,
            locationModel: location,
            account: account,
            now: now,
            filterStore: filterStore,
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

@MainActor
private final class SearchRecordingLocationAdapter: LocationAdapter {
    var authorization: LocationAuthorization
    var onEvent: (@MainActor (LocationAdapterEvent) -> Void)?
    var coordinate: GeoCoordinate?
    var recordedAt: Date
    private(set) var locationRequestCount = 0

    init(
        authorization: LocationAuthorization,
        coordinate: GeoCoordinate?,
        recordedAt: Date,
    ) {
        self.authorization = authorization
        self.coordinate = coordinate
        self.recordedAt = recordedAt
    }

    func requestAuthorization() {}

    func requestLocation() {
        locationRequestCount += 1
        guard authorization == .authorized, let coordinate else {
            onEvent?(.failed(authorization))
            return
        }
        onEvent?(.located(LocationSample(
            coordinate: coordinate,
            horizontalAccuracy: nil,
            recordedAt: recordedAt,
        )))
    }
}

private final class SearchTestClock: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Date

    init(_ value: Date) {
        self.value = value
    }

    func now() -> Date {
        lock.withLock { value }
    }

    func advance(by interval: TimeInterval) {
        lock.withLock {
            value.addTimeInterval(interval)
        }
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
