import XCTest
@testable import Via

@MainActor
final class ReportViewModelTests: XCTestCase {
    func testSimpleCategorySubmitsOccurrenceAndShowsConfirmation() async throws {
        let repository = InMemoryReportRepository()
        let model = makeModel(repository: repository)
        await resolveContext(for: model)

        model.selectCategory(.pickpocket)
        await waitForSubmission(model) {
            if case .confirmed = $0 { return true }
            return false
        }

        let submissions = await repository.submissions()
        let submission = try XCTUnwrap(submissions.first)
        XCTAssertEqual(submission.category, .pickpocket)
        XCTAssertEqual(submission.value, .occurrence)
    }

    func testCrowdingDoesNotSubmitBeforeALevelIsSelected() async {
        let repository = InMemoryReportRepository()
        let model = makeModel(repository: repository)
        await resolveContext(for: model)

        model.selectCategory(.crowding)

        XCTAssertEqual(model.presentedSheet, .crowdingPicker)
        let submissions = await repository.submissions()
        XCTAssertTrue(submissions.isEmpty)
        XCTAssertEqual(model.submissionState, .idle)
    }

    func testEachCrowdingLevelIsPreserved() async throws {
        let repository = InMemoryReportRepository()
        let model = makeModel(repository: repository)
        await resolveContext(for: model)

        for level in CrowdingLevel.allCases {
            model.selectCategory(.crowding)
            model.selectCrowdingLevel(level)
            await waitForSubmission(model) {
                if case .confirmed = $0 { return true }
                return false
            }

            let submissions = await repository.submissions()
            let submission = try XCTUnwrap(submissions.last)
            XCTAssertEqual(submission.category, .crowding)
            XCTAssertEqual(submission.value, .crowding(level))
            model.finishConfirmation()
        }

        let submissions = await repository.submissions()
        XCTAssertEqual(submissions.count, 4)
    }

    func testCancellingCrowdingSheetCreatesNoSubmission() async {
        let repository = InMemoryReportRepository()
        let model = makeModel(repository: repository)
        await resolveContext(for: model)

        model.selectCategory(.crowding)
        model.cancelPresentedSheet()

        XCTAssertNil(model.presentedSheet)
        let submissions = await repository.submissions()
        XCTAssertTrue(submissions.isEmpty)
        XCTAssertEqual(model.submissionState, .idle)
    }

    func testConcurrentCardTapsCreateOnlyOneSubmission() async {
        let repository = SlowReportRepository()
        let model = makeModel(repository: repository)
        await resolveContext(for: model)

        model.selectCategory(.pickpocket)
        model.selectCategory(.restroomsClosed)
        await waitForSubmission(model) {
            if case .confirmed = $0 { return true }
            return false
        }

        let submissions = await repository.submissions()
        XCTAssertEqual(submissions.count, 1)
        XCTAssertEqual(submissions.first?.category, .pickpocket)
    }

    func testFailureKeepsSubmissionAndRetryUsesTheSameIdentityAndContext() async throws {
        let repository = ScriptedReportRepository(failuresBeforeSuccess: 1)
        let fixedID = UUID(uuidString: "00000000-0000-0000-0000-000000000031")!
        let model = makeModel(repository: repository, makeID: { fixedID })
        await resolveContext(for: model)
        let stationBeforeFailure = model.contextResolver.state.selection?.station

        model.selectCategory(.passageObstructed)
        await waitForSubmission(model) {
            if case .failed = $0 { return true }
            return false
        }

        guard case .failed(let failedSubmission, .unavailable) = model.submissionState else {
            return XCTFail("Expected a preserved failed submission")
        }
        XCTAssertEqual(failedSubmission.id, fixedID)
        XCTAssertEqual(Optional(failedSubmission.context.station), stationBeforeFailure)

        model.retrySubmission()
        await waitForSubmission(model) {
            if case .confirmed = $0 { return true }
            return false
        }

        let attempts = await repository.attempts()
        XCTAssertEqual(attempts.count, 2)
        XCTAssertEqual(attempts[0], attempts[1])
    }

    func testDoneReturnsToCardsAndKeepsTheStation() async {
        let repository = InMemoryReportRepository()
        let model = makeModel(repository: repository)
        await resolveContext(for: model)
        let station = model.contextResolver.state.selection?.station

        model.selectCategory(.stopNotServed)
        await waitForSubmission(model) {
            if case .confirmed = $0 { return true }
            return false
        }
        model.finishConfirmation()

        XCTAssertEqual(model.submissionState, .idle)
        XCTAssertEqual(model.contextResolver.state.selection?.station, station)
        XCTAssertTrue(model.canSubmit)
    }

    func testCardsCannotSubmitWithoutAStation() async {
        let repository = InMemoryReportRepository()
        let resolver = ReportContextResolver(
            locationModel: LocationModel(adapter: InMemoryLocationAdapter(
                authorization: .denied,
                coordinate: nil
            )),
            networkRepository: InMemoryNetworkRepository(area: .init(stations: [], routes: []))
        )
        let model = ReportViewModel(
            contextResolver: resolver,
            repository: repository,
            searchRepository: InMemorySearchRepository()
        )

        model.loadIfNeeded()
        await waitForContext(model) {
            if case .unavailable = $0 { return true }
            return false
        }
        model.selectCategory(.pickpocket)

        XCTAssertFalse(model.canSubmit)
        XCTAssertEqual(model.submissionState, .idle)
        let submissions = await repository.submissions()
        XCTAssertTrue(submissions.isEmpty)
    }

    func testReloadRefreshesActiveJourneyContext() async {
        let first = ActiveJourneyContext(
            journeyID: JourneyID(rawValue: "journey:first"),
            lineID: RouteID(rawValue: "route:first"),
            vehicleID: nil
        )
        let second = ActiveJourneyContext(
            journeyID: JourneyID(rawValue: "journey:second"),
            lineID: RouteID(rawValue: "route:second"),
            vehicleID: nil
        )
        let provider = MutableActiveJourneyProvider(context: first)
        let model = makeModel(
            repository: InMemoryReportRepository(),
            activeJourneyProvider: provider
        )

        model.loadIfNeeded()
        await waitForActiveJourney(model, first)

        provider.context = second
        model.loadIfNeeded()
        await waitForActiveJourney(model, second)
    }

    func testStationSearchWaitsForTwoCharactersAndFiltersAddresses() async {
        let search = RecordingReportSearchRepository(response: SearchResponse(
            results: [.previewAddress, .previewStation],
            addressSource: .ok
        ))
        let model = makeModel(
            repository: InMemoryReportRepository(),
            searchRepository: search
        )

        model.stationQuery = "c"
        try? await Task.sleep(for: .milliseconds(300))
        let shortQueries = await search.queries()
        XCTAssertTrue(shortQueries.isEmpty)
        XCTAssertEqual(model.stationSearchState, .idle)

        model.stationQuery = "ch"
        await waitForStationSearch(model) {
            if case .loaded = $0 { return true }
            return false
        }

        let queries = await search.queries()
        XCTAssertEqual(queries, ["ch"])
        guard case .station(let station) = SearchResult.previewStation else {
            return XCTFail("Preview station fixture changed")
        }
        XCTAssertEqual(model.stationSearchState, .loaded([station]))
    }

    func testSubmittingStationSearchRunsImmediatelyWithoutDuplicatingTheDebouncedRequest() async {
        let search = RecordingReportSearchRepository(response: SearchResponse(
            results: [.previewStation],
            addressSource: .ok
        ))
        let model = makeModel(
            repository: InMemoryReportRepository(),
            searchRepository: search
        )

        model.stationQuery = "ch"
        model.searchStationsImmediately()

        await waitForStationSearch(model) {
            if case .loaded = $0 { return true }
            return false
        }
        try? await Task.sleep(for: .milliseconds(300))

        let queries = await search.queries()
        XCTAssertEqual(queries, ["ch"])
    }

    func testClearingStationSearchRestoresIdleState() async {
        let search = RecordingReportSearchRepository(response: SearchResponse(
            results: [.previewStation],
            addressSource: .ok
        ))
        let model = makeModel(
            repository: InMemoryReportRepository(),
            searchRepository: search
        )

        model.stationQuery = "ch"
        model.searchStationsImmediately()
        await waitForStationSearch(model) {
            if case .loaded = $0 { return true }
            return false
        }

        model.clearStationQuery()

        XCTAssertEqual(model.stationQuery, "")
        XCTAssertEqual(model.stationSearchState, .idle)
    }

    private func makeModel(
        repository: any ReportRepository,
        searchRepository: any SearchRepository = InMemorySearchRepository.preview,
        activeJourneyProvider: any ActiveJourneyProvider = NoActiveJourneyProvider(),
        makeID: @escaping @Sendable () -> UUID = { UUID() }
    ) -> ReportViewModel {
        let route = RouteBadge(
            id: RouteID(rawValue: "metro:1"),
            shortName: "1",
            mode: .metro,
            colorHex: "#FFCD00",
            textColorHex: "#000000"
        )
        let station = NetworkStation(
            id: StationID(rawValue: "station"),
            name: "Châtelet",
            coordinate: GeoCoordinate(latitude: 48.8583, longitude: 2.3470),
            routeIDs: [route.id]
        )
        let resolver = ReportContextResolver(
            locationModel: LocationModel(adapter: InMemoryLocationAdapter(
                coordinate: GeoCoordinate(latitude: 48.8584, longitude: 2.3471)
            )),
            networkRepository: InMemoryNetworkRepository(
                area: StationsArea(stations: [station], routes: [route])
            )
        )
        return ReportViewModel(
            contextResolver: resolver,
            repository: repository,
            searchRepository: searchRepository,
            activeJourneyProvider: activeJourneyProvider,
            makeID: makeID
        )
    }

    private func resolveContext(for model: ReportViewModel) async {
        model.loadIfNeeded()
        await waitForContext(model) { $0.selection != nil }
    }

    private func waitForContext(
        _ model: ReportViewModel,
        matching predicate: (ReportContextResolutionState) -> Bool
    ) async {
        for _ in 0..<100 {
            if predicate(model.contextResolver.state) { return }
            try? await Task.sleep(for: .milliseconds(5))
        }
        XCTFail("Timed out waiting for report context")
    }

    private func waitForSubmission(
        _ model: ReportViewModel,
        matching predicate: (ReportSubmissionState) -> Bool
    ) async {
        for _ in 0..<100 {
            if predicate(model.submissionState) { return }
            try? await Task.sleep(for: .milliseconds(5))
        }
        XCTFail("Timed out waiting for report submission")
    }

    private func waitForStationSearch(
        _ model: ReportViewModel,
        matching predicate: (ReportStationSearchState) -> Bool
    ) async {
        for _ in 0..<150 {
            if predicate(model.stationSearchState) { return }
            try? await Task.sleep(for: .milliseconds(5))
        }
        XCTFail("Timed out waiting for station search")
    }

    private func waitForActiveJourney(
        _ model: ReportViewModel,
        _ expected: ActiveJourneyContext
    ) async {
        for _ in 0..<100 {
            if model.activeJourney == expected { return }
            await Task.yield()
        }
        XCTFail("Timed out waiting for active journey context")
    }
}

@MainActor
private final class MutableActiveJourneyProvider: ActiveJourneyProvider {
    var context: ActiveJourneyContext?

    init(context: ActiveJourneyContext?) {
        self.context = context
    }

    func activeJourney() async -> ActiveJourneyContext? { context }
}

private actor SlowReportRepository: ReportRepository {
    private var stored: [ReportSubmission] = []

    func submit(_ submission: ReportSubmission) async throws -> StationLiveStatus {
        stored.append(submission)
        try await Task.sleep(for: .milliseconds(50))
        return .empty(stationID: submission.context.station.id)
    }

    func stationStatus(
        stationID: StationID,
        lineID: RouteID?,
        vehicleID: String?
    ) async throws -> StationLiveStatus {
        .empty(stationID: stationID)
    }

    func submissions() -> [ReportSubmission] { stored }
}

private actor ScriptedReportRepository: ReportRepository {
    private var remainingFailures: Int
    private var recordedAttempts: [ReportSubmission] = []

    init(failuresBeforeSuccess: Int) {
        remainingFailures = failuresBeforeSuccess
    }

    func submit(_ submission: ReportSubmission) async throws -> StationLiveStatus {
        recordedAttempts.append(submission)
        if remainingFailures > 0 {
            remainingFailures -= 1
            throw ViaError.unavailable
        }
        return .empty(stationID: submission.context.station.id)
    }

    func stationStatus(
        stationID: StationID,
        lineID: RouteID?,
        vehicleID: String?
    ) async throws -> StationLiveStatus {
        .empty(stationID: stationID)
    }

    func attempts() -> [ReportSubmission] { recordedAttempts }
}

private actor RecordingReportSearchRepository: SearchRepository {
    let response: SearchResponse
    private var recordedQueries: [String] = []

    init(response: SearchResponse) {
        self.response = response
    }

    func search(
        query: String,
        near coordinate: GeoCoordinate?,
        bikeStationsOnly: Bool
    ) async throws -> SearchResponse {
        recordedQueries.append(query)
        return response
    }

    func queries() -> [String] { recordedQueries }
}
