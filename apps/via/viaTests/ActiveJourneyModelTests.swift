import XCTest
@testable import Via

@MainActor
final class ActiveJourneyModelTests: XCTestCase {
    func testActivationPersistsAndRestoresTheSelectedJourney() async throws {
        let journey = JourneyResult.mapPreview.journeys[0]
        let store = InMemoryActiveJourneyStore()
        let adapter = InMemoryLocationAdapter()
        let location = LocationModel(adapter: adapter)
        let now = journey.departureAt.addingTimeInterval(-5 * 60)
        let first = makeModel(location: location, store: store, now: now)

        await first.go(
            journey: journey,
            destination: destination,
            source: .realtime,
            allowsBackgroundTracking: true
        )

        XCTAssertEqual(first.session?.journey.id, journey.id)
        XCTAssertTrue(location.backgroundAuthorizationGranted)
        XCTAssertEqual(first.activationAction(for: journey, at: now), .active)

        let restoredActivityManager = RecordingJourneyActivityManager()
        let restored = makeModel(
            location: location,
            store: store,
            activityManager: restoredActivityManager,
            now: now
        )
        await restored.restore()

        XCTAssertEqual(restored.session?.journey, journey)
        XCTAssertEqual(restored.session?.destination, destination)
        XCTAssertEqual(restored.phase, .scheduled(5 * 60))
        XCTAssertTrue(restored.requiresResume)
        XCTAssertFalse(restored.isTracking)
        XCTAssertTrue(restored.session?.allowsBackgroundTracking == true)
        let pausedState = await restoredActivityManager.lastUpdate
        XCTAssertEqual(pausedState?.phase, JourneyActivityAttributes.Phase.paused)
        XCTAssertEqual(restored.activationAction(for: journey, at: now), .resume)

        await restored.resume()

        XCTAssertFalse(restored.requiresResume)
        XCTAssertTrue(restored.isTracking)
        XCTAssertTrue(adapter.allowsBackgroundUpdates)
    }

    func testFutureActivationDoesNotRequestLocationUntilGo() async {
        let journey = JourneyResult.mapPreview.journeys[0]
        let adapter = InMemoryLocationAdapter()
        let location = LocationModel(adapter: adapter)
        let model = makeModel(
            location: location,
            now: journey.departureAt.addingTimeInterval(-20 * 60)
        )

        await model.activate(
            journey: journey,
            destination: destination,
            source: .realtime
        )

        XCTAssertFalse(model.session?.isTrackingStarted == true)
        XCTAssertFalse(model.isTracking)
        XCTAssertNil(model.session?.lastCoordinate)
        XCTAssertFalse(adapter.backgroundAuthorizationGranted)

        await model.startTracking(allowsBackgroundTracking: true)

        XCTAssertTrue(model.session?.isTrackingStarted == true)
        XCTAssertTrue(model.isTracking)
        XCTAssertNotNil(model.session?.lastCoordinate)
        XCTAssertTrue(adapter.backgroundAuthorizationGranted)
    }

    func testLiveActivityStateKeepsDepartureCountdownSemantic() async {
        let journey = JourneyResult.mapPreview.journeys[0]
        let activityManager = RecordingJourneyActivityManager()
        let model = makeModel(
            activityManager: activityManager,
            now: journey.departureAt.addingTimeInterval(-5 * 60)
        )

        await model.activate(
            journey: journey,
            destination: destination,
            source: .realtime
        )

        let state = await activityManager.lastStart
        XCTAssertEqual(state?.phase, JourneyActivityAttributes.Phase.scheduled)
        XCTAssertEqual(state?.departureAt, journey.departureAt)
        XCTAssertEqual(state?.phaseTitle, "Départ")
        XCTAssertEqual(state?.instructionTitle, "Trajet vers La Défense")
    }

    func testLiveActivityDeepLinkTargetsTheActiveJourney() {
        let url = JourneyActivityAttributes(journeyID: "test:journey").journeyURL
        let components = url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false) }

        XCTAssertEqual(url?.scheme, "via")
        XCTAssertEqual(url?.host, "journey")
        XCTAssertEqual(url?.path.removingPercentEncoding, "/test:journey")
        XCTAssertEqual(
            components?.queryItems?.first(where: { $0.name == "mode" })?.value,
            "active"
        )
    }

    func testManualProgressControlsRemainInsideJourneyBounds() async {
        let journey = JourneyResult.mapPreview.journeys[0]
        let now = journey.departureAt
        let model = makeModel(now: now)
        await model.go(
            journey: journey,
            destination: destination,
            source: .realtime,
            allowsBackgroundTracking: false
        )

        await model.moveToPreviousSection()
        XCTAssertEqual(model.session?.currentSectionIndex, 0)

        for _ in journey.sections.indices {
            await model.moveToNextSection()
        }
        XCTAssertEqual(model.session?.currentSectionIndex, journey.sections.count - 1)
    }

    func testManualFinishPublishesArrivalAndClearsPersistedSession() async throws {
        let journey = JourneyResult.mapPreview.journeys[0]
        let store = InMemoryActiveJourneyStore()
        let model = makeModel(store: store, now: journey.arrivalAt)
        await model.go(
            journey: journey,
            destination: destination,
            source: .realtime,
            allowsBackgroundTracking: false
        )

        await model.finishJourney()

        XCTAssertNil(model.session)
        XCTAssertEqual(model.arrival?.destinationName, destination.name)
        let persisted = await store.load()
        XCTAssertNil(persisted)
    }

    func testLocationAtDestinationAfterFinalStepCompletesJourney() async throws {
        let journey = JourneyResult.mapPreview.journeys[0]
        let store = InMemoryActiveJourneyStore()
        let location = LocationModel(adapter: InMemoryLocationAdapter(
            authorization: .denied,
            coordinate: nil
        ))
        let model = makeModel(
            location: location,
            store: store,
            now: journey.departureAt
        )
        await model.go(
            journey: journey,
            destination: destination,
            source: .realtime,
            allowsBackgroundTracking: false
        )

        let finalCoordinate = try XCTUnwrap(journey.sections.last?.to.coordinate)
        await model.receive(
            LocationSample(
                coordinate: finalCoordinate,
                horizontalAccuracy: 30,
                recordedAt: journey.arrivalAt
            ),
            at: journey.arrivalAt
        )

        XCTAssertNil(model.session)
        XCTAssertEqual(model.arrival?.destinationName, destination.name)
        let persisted = await store.load()
        XCTAssertNil(persisted)
    }

    func testFastestAlternativeIsProposedAndAcceptedWithoutSilentReplacement() async {
        let result = JourneyResult.mapPreview
        let current = result.journeys[0]
        let model = makeModel(
            repository: InMemoryJourneyRepository(result: result),
            now: current.departureAt
        )
        await model.go(
            journey: current,
            destination: destination,
            source: .realtime,
            allowsBackgroundTracking: false
        )

        model.checkForAlternative()
        await waitUntil { model.alternative != nil }

        let proposed = model.alternative?.journey
        XCTAssertEqual(model.session?.journey.id, current.id)
        XCTAssertEqual(
            proposed?.arrivalAt,
            result.journeys.dropFirst().map(\.arrivalAt).min()
        )

        await model.acceptBestAlternative()

        XCTAssertEqual(model.session?.journey.id, proposed?.id)
        XCTAssertNil(model.alternative)
    }

    func testExpiredActiveJourneyIsClearedWhenTheAppBecomesActive() async throws {
        let journey = JourneyResult.mapPreview.journeys[0]
        let store = InMemoryActiveJourneyStore()
        let clock = ActiveJourneyTestClock(journey.departureAt)
        let model = makeModel(store: store, now: { clock.value })
        await model.activate(
            journey: journey,
            destination: destination,
            source: .realtime
        )

        clock.value = journey.arrivalAt.addingTimeInterval(30 * 60 + 1)
        await model.sceneBecameActive()

        XCTAssertNil(model.session)
        let persisted = await store.load()
        XCTAssertNil(persisted)
    }

    func testCancelledRecalculationCannotPublishAnAlternative() async {
        let current = JourneyResult.mapPreview.journeys[0]
        let repository = SuspendedJourneyRepository()
        let model = makeModel(repository: repository, now: current.departureAt)
        await model.go(
            journey: current,
            destination: destination,
            source: .realtime,
            allowsBackgroundTracking: false
        )

        model.checkForAlternative()
        await repository.waitUntilRequested()
        await model.cancelJourney()
        await repository.resolve(with: .mapPreview)
        await Task.yield()

        XCTAssertNil(model.session)
        XCTAssertNil(model.alternative)
        XCTAssertEqual(model.recalculationState, .idle)
    }

    func testUnavailableRecalculationRemainsVisibleForRetry() async {
        let current = JourneyResult.mapPreview.journeys[0]
        let result = JourneyResult(
            status: .unavailable,
            source: nil,
            generatedAt: current.departureAt,
            journeys: []
        )
        let model = makeModel(
            repository: InMemoryJourneyRepository(result: result),
            now: current.departureAt
        )
        await model.go(
            journey: current,
            destination: destination,
            source: .realtime,
            allowsBackgroundTracking: false
        )

        model.checkForAlternative()
        await waitUntil { model.recalculationState == .failed(.unavailable) }

        XCTAssertEqual(model.recalculationState, .failed(.unavailable))
    }

    func testConnectivityLossMarksTheCachedJourneyOfflineWithoutReplanning() async {
        let journey = JourneyResult.mapPreview.journeys[0]
        let connectivity = InMemoryConnectivityMonitor(isConnected: true)
        let model = makeModel(connectivity: connectivity, now: journey.departureAt)
        await model.activate(
            journey: journey,
            destination: destination,
            source: .realtime
        )

        connectivity.update(isConnected: false)

        XCTAssertTrue(model.isOffline)
    }

    func testConnectivityLossCancelsAnInFlightRecalculation() async {
        let journey = JourneyResult.mapPreview.journeys[0]
        let repository = SuspendedJourneyRepository()
        let connectivity = InMemoryConnectivityMonitor(isConnected: true)
        let model = makeModel(
            repository: repository,
            connectivity: connectivity,
            now: journey.departureAt
        )
        await model.go(
            journey: journey,
            destination: destination,
            source: .realtime,
            allowsBackgroundTracking: false
        )

        model.checkForAlternative()
        await repository.waitUntilRequested()
        connectivity.update(isConnected: false)
        await repository.resolve(with: .mapPreview)
        await Task.yield()

        XCTAssertTrue(model.isOffline)
        XCTAssertNil(model.alternative)
        XCTAssertEqual(model.recalculationState, .offline)
    }

    func testReconnectionClearsOfflineStateAndRefreshesLiveActivity() async {
        let journey = JourneyResult.mapPreview.journeys[0]
        let connectivity = InMemoryConnectivityMonitor(isConnected: true)
        let activityManager = RecordingJourneyActivityManager()
        let model = makeModel(
            activityManager: activityManager,
            connectivity: connectivity,
            now: journey.departureAt
        )
        await model.activate(
            journey: journey,
            destination: destination,
            source: .realtime
        )

        connectivity.update(isConnected: false)
        await waitUntilAsync { await activityManager.lastUpdate?.isOffline == true }
        connectivity.update(isConnected: true)
        await waitUntilAsync { await activityManager.lastUpdate?.isOffline == false }

        XCTAssertFalse(model.isOffline)
        XCTAssertEqual(model.recalculationState, .idle)
    }

    func testOfflineJourneyKeepsUsingAFreshGPSFix() async throws {
        let journey = JourneyResult.mapPreview.journeys[0]
        let connectivity = InMemoryConnectivityMonitor(isConnected: true)
        let coordinate = try XCTUnwrap(journey.sections.first?.from.coordinate)
        let location = LocationModel(adapter: InMemoryLocationAdapter(coordinate: coordinate))
        let model = makeModel(
            location: location,
            connectivity: connectivity,
            now: journey.departureAt
        )

        await model.go(
            journey: journey,
            destination: destination,
            source: .realtime,
            allowsBackgroundTracking: false
        )
        connectivity.update(isConnected: false)

        XCTAssertFalse(model.isPositionEstimated)
        XCTAssertTrue(model.hasLiveLocationFix)
        XCTAssertTrue(model.progress(at: journey.departureAt)?.isLocationDerived == true)
    }

    func testStaleLocationFallsBackToTimetableWhileConnected() async {
        let journey = JourneyResult.mapPreview.journeys[0]
        let clock = ActiveJourneyTestClock(journey.departureAt)
        let model = makeModel(now: { clock.value })

        await model.go(
            journey: journey,
            destination: destination,
            source: .realtime,
            allowsBackgroundTracking: false
        )

        clock.value = journey.departureAt.addingTimeInterval(
            ActiveJourneyRules.locationFreshnessInterval + 1
        )
        await model.receive(
            LocationSample(
                coordinate: journey.sections[0].from.coordinate,
                horizontalAccuracy: 10,
                recordedAt: journey.departureAt
            ),
            at: clock.value
        )

        XCTAssertTrue(model.isPositionEstimated)
        XCTAssertFalse(model.hasLiveLocationFix)
    }

    func testFreshLocationReturnsToLiveWhileOfflineAfterFixBecomesStale() async {
        let journey = JourneyResult.mapPreview.journeys[0]
        let clock = ActiveJourneyTestClock(journey.departureAt)
        let connectivity = InMemoryConnectivityMonitor(isConnected: false)
        let coordinate = journey.sections[0].from.coordinate
        let adapter = InMemoryLocationAdapter(coordinate: coordinate)
        let location = LocationModel(adapter: adapter)
        let model = makeModel(
            location: location,
            connectivity: connectivity,
            now: { clock.value }
        )

        await model.go(
            journey: journey,
            destination: destination,
            source: .realtime,
            allowsBackgroundTracking: false
        )
        XCTAssertFalse(model.isPositionEstimated)

        clock.value = journey.departureAt.addingTimeInterval(
            ActiveJourneyRules.locationFreshnessInterval + 1
        )
        await model.receive(
            LocationSample(
                coordinate: coordinate,
                horizontalAccuracy: 10,
                recordedAt: journey.departureAt
            ),
            at: clock.value
        )
        XCTAssertTrue(model.isPositionEstimated)

        adapter.updateJourneyLocation(
            coordinate,
            recordedAt: clock.value
        )
        await waitUntil { model.hasLiveLocationFix }

        XCTAssertFalse(model.isPositionEstimated)
    }

    func testDepartureRevisionPreservesRunningSessionProgressAndTracking() async {
        let journey = JourneyResult.mapPreview.journeys[0]
        let model = makeModel(now: journey.departureAt)
        let policy = JourneyPlanningPolicy(
            requiredModes: [.rer],
            requiresAccessibleStations: true
        )
        await model.go(
            journey: journey,
            destination: destination,
            source: .realtime,
            planningPolicy: policy,
            allowsBackgroundTracking: false
        )
        await model.moveToNextSection()
        let previousIndex = model.session?.currentSectionIndex
        let revised = Journey(
            id: journey.id,
            qualifier: journey.qualifier,
            durationSeconds: journey.durationSeconds + 300,
            walkingDurationSeconds: journey.walkingDurationSeconds,
            transferCount: journey.transferCount,
            departureAt: journey.departureAt,
            arrivalAt: journey.arrivalAt.addingTimeInterval(300),
            status: journey.status,
            warnings: journey.warnings,
            accessibility: journey.accessibility,
            peak: journey.peak,
            sections: journey.sections
        )

        await model.applyDepartureRevision(revised)

        XCTAssertEqual(model.session?.journey, revised)
        XCTAssertEqual(model.session?.currentSectionIndex, previousIndex)
        XCTAssertEqual(model.session?.planningPolicy, policy)
        XCTAssertTrue(model.isTracking)
        XCTAssertNil(model.alternative)
    }

    func testOldSessionPayloadRestoresACompatiblePlanningPolicy() throws {
        let journey = JourneyResult.mapPreview.journeys[0]
        let session = ActiveJourneySession(
            journey: journey,
            destination: destination,
            source: .realtime,
            planningPolicy: JourneyPlanningPolicy(requiresAccessibleStations: true),
            currentSectionIndex: 0,
            lastCoordinate: nil,
            horizontalAccuracy: nil,
            manualOverrideUntil: nil,
            isTrackingStarted: false,
            allowsBackgroundTracking: false
        )
        let encoded = try JSONEncoder().encode(session)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        // The shape written before the policy existed: the bare flag, no policy.
        object.removeValue(forKey: "planningPolicy")
        object["requiresAccessibleStations"] = true
        let legacy = try JSONSerialization.data(withJSONObject: object)

        let decoded = try JSONDecoder().decode(ActiveJourneySession.self, from: legacy)

        XCTAssertTrue(decoded.planningPolicy.requiresAccessibleStations)
        XCTAssertTrue(decoded.planningPolicy.requiredModes.isEmpty)
    }

    private var destination: JourneyDestination {
        .address(
            id: "test:destination",
            name: "La Défense",
            context: "Puteaux",
            coordinate: GeoCoordinate(latitude: 48.8918, longitude: 2.2380)
        )
    }

    private func makeModel(
        location: LocationModel = LocationModel(adapter: InMemoryLocationAdapter()),
        repository: any JourneyRepository = InMemoryJourneyRepository(result: .mapPreview),
        store: any ActiveJourneyStore = InMemoryActiveJourneyStore(),
        activityManager: any JourneyActivityManaging = NoOpJourneyActivityManager(),
        connectivity: any ConnectivityMonitoring = InMemoryConnectivityMonitor(),
        now: Date
    ) -> ActiveJourneyModel {
        makeModel(
            location: location,
            repository: repository,
            store: store,
            activityManager: activityManager,
            connectivity: connectivity,
            now: { now }
        )
    }

    private func makeModel(
        location: LocationModel = LocationModel(adapter: InMemoryLocationAdapter()),
        repository: any JourneyRepository = InMemoryJourneyRepository(result: .mapPreview),
        store: any ActiveJourneyStore = InMemoryActiveJourneyStore(),
        activityManager: any JourneyActivityManaging = NoOpJourneyActivityManager(),
        connectivity: any ConnectivityMonitoring = InMemoryConnectivityMonitor(),
        now: @escaping @Sendable () -> Date
    ) -> ActiveJourneyModel {
        ActiveJourneyModel(
            locationModel: location,
            journeyRepository: repository,
            store: store,
            activityManager: activityManager,
            connectivity: connectivity,
            now: now
        )
    }

    private func waitUntil(
        _ predicate: @escaping @MainActor () -> Bool,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        for _ in 0..<200 {
            if predicate() { return }
            await Task.yield()
            try? await Task.sleep(for: .milliseconds(5))
        }
        XCTFail("Timed out waiting for active journey state", file: file, line: line)
    }

    private func waitUntilAsync(
        _ predicate: @escaping @MainActor () async -> Bool,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        for _ in 0..<200 {
            if await predicate() { return }
            await Task.yield()
            try? await Task.sleep(for: .milliseconds(5))
        }
        XCTFail("Timed out waiting for active journey state", file: file, line: line)
    }
}

private final class ActiveJourneyTestClock: @unchecked Sendable {
    private let lock = NSLock()
    private var storedValue: Date

    init(_ value: Date) {
        storedValue = value
    }

    var value: Date {
        get { lock.withLock { storedValue } }
        set { lock.withLock { storedValue = newValue } }
    }
}

private actor SuspendedJourneyRepository: JourneyRepository {
    private var continuation: CheckedContinuation<JourneyResult, Never>?
    private var requestWaiters: [CheckedContinuation<Void, Never>] = []

    func plan(_ request: JourneyRequest) async -> JourneyResult {
        for waiter in requestWaiters { waiter.resume() }
        requestWaiters.removeAll()
        return await withCheckedContinuation { continuation = $0 }
    }

    func waitUntilRequested() async {
        if continuation != nil { return }
        await withCheckedContinuation { requestWaiters.append($0) }
    }

    func resolve(with result: JourneyResult) {
        continuation?.resume(returning: result)
        continuation = nil
    }
}

private actor RecordingJourneyActivityManager: JourneyActivityManaging {
    private(set) var lastStart: JourneyActivityAttributes.ContentState?
    private(set) var lastUpdate: JourneyActivityAttributes.ContentState?

    func start(
        attributes: JourneyActivityAttributes,
        state: JourneyActivityAttributes.ContentState,
        staleAt: Date
    ) {
        lastStart = state
    }

    func update(
        journeyID: JourneyID,
        state: JourneyActivityAttributes.ContentState,
        staleAt: Date
    ) {
        lastUpdate = state
    }

    func end(
        journeyID: JourneyID,
        finalState: JourneyActivityAttributes.ContentState,
        dismissAt: Date
    ) {}
}
