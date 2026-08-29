import XCTest
@testable import Via

@MainActor
final class LocationModelTests: XCTestCase {
    func testNotDeterminedAuthorizationFlowsToLocated() async {
        let coordinate = GeoCoordinate(latitude: 48.8566, longitude: 2.3522)
        let adapter = RecordingLocationAdapter(
            authorization: .notDetermined,
            coordinate: coordinate
        )
        let model = LocationModel(adapter: adapter)

        let result = await model.requestCurrentLocation()

        XCTAssertEqual(result, coordinate)
        XCTAssertEqual(model.state, .located(coordinate))
        XCTAssertEqual(adapter.authorizationRequestCount, 1)
        XCTAssertEqual(adapter.locationRequestCount, 1)
    }

    func testDeniedAuthorizationBlocksOnlyCurrentLocation() async {
        let adapter = RecordingLocationAdapter(authorization: .denied, coordinate: nil)
        let model = LocationModel(adapter: adapter)

        let result = await model.requestCurrentLocation()

        XCTAssertNil(result)
        XCTAssertEqual(model.state, .failed(.denied))
        XCTAssertEqual(adapter.authorizationRequestCount, 0)
        XCTAssertEqual(adapter.locationRequestCount, 0)
    }

    func testStationsAndSearchShareOneAdapterOwner() async {
        let coordinate = GeoCoordinate(latitude: 48.8566, longitude: 2.3522)
        let adapter = RecordingLocationAdapter(authorization: .authorized, coordinate: coordinate)
        let model = LocationModel(adapter: adapter)
        let stations = StationsViewModel(
            locationModel: model,
            networkRepository: InMemoryNetworkRepository(
                area: StationsArea(stations: [], routes: [])
            ),
            departuresRepository: InMemoryDeparturesRepository()
        )
        let search = SearchViewModel(
            repository: InMemorySearchRepository.preview,
            journeyRepository: InMemoryJourneyRepository(result: .mapPreview),
            locationModel: model
        )

        stations.loadIfNeeded()
        let searchCoordinate = await model.requestCurrentLocation()

        XCTAssertEqual(searchCoordinate, coordinate)
        XCTAssertEqual(adapter.locationRequestCount, 1)
        XCTAssertEqual(model.coordinate, coordinate)
        XCTAssertNotNil(search)
    }

    func testJourneyTrackingRequestsBackgroundAccessAndPublishesAccuracy() async {
        let coordinate = GeoCoordinate(latitude: 48.8566, longitude: 2.3522)
        let adapter = InMemoryLocationAdapter(
            coordinate: coordinate,
            horizontalAccuracy: 18
        )
        let model = LocationModel(adapter: adapter)

        let updates = model.startJourneyTracking(allowsBackgroundUpdates: true)
        var iterator = updates.makeAsyncIterator()
        let sample = await iterator.next()

        XCTAssertEqual(sample?.coordinate, coordinate)
        XCTAssertEqual(sample?.horizontalAccuracy, 18)
        XCTAssertTrue(model.backgroundAuthorizationGranted)
        XCTAssertTrue(adapter.allowsBackgroundUpdates)

        model.stopJourneyTracking()
    }

    func testForegroundJourneyTrackingDoesNotEnableBackgroundUpdates() async {
        let adapter = InMemoryLocationAdapter()
        let model = LocationModel(adapter: adapter)

        let updates = model.startJourneyTracking(allowsBackgroundUpdates: false)
        var iterator = updates.makeAsyncIterator()
        _ = await iterator.next()

        XCTAssertFalse(model.backgroundAuthorizationGranted)
        XCTAssertFalse(adapter.allowsBackgroundUpdates)

        model.stopJourneyTracking()
    }

    func testJourneyTrackingDoesNotReplayPreviousJourneySample() async {
        let first = GeoCoordinate(latitude: 48.8566, longitude: 2.3522)
        let second = GeoCoordinate(latitude: 48.8666, longitude: 2.3622)
        let adapter = InMemoryLocationAdapter(coordinate: first)
        let model = LocationModel(adapter: adapter)

        var firstIterator = model
            .startJourneyTracking(allowsBackgroundUpdates: false)
            .makeAsyncIterator()
        let firstSample = await firstIterator.next()
        XCTAssertEqual(firstSample?.coordinate, first)
        model.stopJourneyTracking()

        adapter.coordinate = second
        var secondIterator = model
            .startJourneyTracking(allowsBackgroundUpdates: false)
            .makeAsyncIterator()
        let secondSample = await secondIterator.next()
        XCTAssertEqual(secondSample?.coordinate, second)
        model.stopJourneyTracking()
    }

    func testFreshLocationIgnoresTheCachedCoordinate() async {
        let cached = GeoCoordinate(latitude: 48.8566, longitude: 2.3522)
        let fresh = GeoCoordinate(latitude: 48.8666, longitude: 2.3622)
        let adapter = InMemoryLocationAdapter(coordinate: cached)
        let model = LocationModel(adapter: adapter)

        let initialCoordinate = await model.requestCurrentLocation()
        XCTAssertEqual(initialCoordinate, cached)

        adapter.coordinate = fresh
        let freshCoordinate = await model.requestFreshLocation()

        XCTAssertEqual(freshCoordinate, fresh)
    }

    func testFreshLocationReturnsAfterTimeoutWhenAdapterStaysSilent() async {
        let adapter = SilentLocationAdapter()
        let model = LocationModel(adapter: adapter)

        let coordinate = await model.requestFreshLocation(timeout: .milliseconds(20))

        XCTAssertNil(coordinate)
        XCTAssertEqual(adapter.locationRequestCount, 1)
    }

    func testCachedLocationExpiresAndRefreshesAtTheNextRequest() async {
        let clock = TestClock(Date(timeIntervalSince1970: 1_000))
        let first = GeoCoordinate(latitude: 48.8566, longitude: 2.3522)
        let second = GeoCoordinate(latitude: 48.8666, longitude: 2.3622)
        let adapter = RecordingLocationAdapter(
            authorization: .authorized,
            coordinate: first,
            recordedAt: clock.now()
        )
        let model = LocationModel(adapter: adapter, now: clock.now)

        let firstResult = await model.requestCurrentLocation()
        XCTAssertEqual(firstResult, first)
        XCTAssertEqual(adapter.locationRequestCount, 1)

        clock.advance(by: 59)
        XCTAssertEqual(model.coordinate, first)
        let cachedResult = await model.requestCurrentLocation()
        XCTAssertEqual(cachedResult, first)
        XCTAssertEqual(adapter.locationRequestCount, 1)

        clock.advance(by: 2)
        XCTAssertNil(model.coordinate)
        adapter.coordinate = second
        adapter.recordedAt = clock.now()

        let refreshedResult = await model.requestCurrentLocation()
        XCTAssertEqual(refreshedResult, second)
        XCTAssertEqual(adapter.locationRequestCount, 2)
    }

    func testFutureLocationSampleIsNotReusable() async {
        let clock = TestClock(Date(timeIntervalSince1970: 2_000))
        let coordinate = GeoCoordinate(latitude: 48.8566, longitude: 2.3522)
        let adapter = RecordingLocationAdapter(
            authorization: .authorized,
            coordinate: coordinate,
            recordedAt: clock.now().addingTimeInterval(6)
        )
        let model = LocationModel(adapter: adapter, now: clock.now)

        let result = await model.requestFreshLocation(timeout: .milliseconds(20))
        XCTAssertNil(result)
        XCTAssertNil(model.coordinate)
    }

    func testUpdatedJourneySampleFeedsTheSharedTimestampedCache() async {
        let clock = TestClock(Date(timeIntervalSince1970: 3_000))
        let initial = GeoCoordinate(latitude: 48.8566, longitude: 2.3522)
        let updated = GeoCoordinate(latitude: 48.8666, longitude: 2.3622)
        let adapter = RecordingLocationAdapter(
            authorization: .authorized,
            coordinate: initial,
            recordedAt: clock.now()
        )
        let model = LocationModel(adapter: adapter, now: clock.now)

        let initialResult = await model.requestCurrentLocation()
        XCTAssertEqual(initialResult, initial)
        var updates = model.startJourneyTracking(allowsBackgroundUpdates: false).makeAsyncIterator()
        _ = await updates.next()
        adapter.emit(.updated(LocationSample(
            coordinate: updated,
            horizontalAccuracy: 12,
            recordedAt: clock.now()
        )))

        XCTAssertEqual(model.coordinate, updated)
        XCTAssertEqual(model.lastSample?.horizontalAccuracy, 12)
        model.stopJourneyTracking()
    }

    func testJourneyTrackingDropsSamplesFromBeforeTheSession() async {
        let initial = GeoCoordinate(latitude: 48.8566, longitude: 2.3522)
        let stale = GeoCoordinate(latitude: 48.8666, longitude: 2.3622)
        let fresh = GeoCoordinate(latitude: 48.8766, longitude: 2.3722)
        let adapter = InMemoryLocationAdapter(coordinate: initial)
        let model = LocationModel(adapter: adapter)

        var iterator = model
            .startJourneyTracking(allowsBackgroundUpdates: false)
            .makeAsyncIterator()
        _ = await iterator.next()

        adapter.updateJourneyLocation(stale, recordedAt: .distantPast)
        adapter.updateJourneyLocation(fresh)
        let nextSample = await iterator.next()

        XCTAssertEqual(nextSample?.coordinate, fresh)
        model.stopJourneyTracking()
    }
}

@MainActor
private final class SilentLocationAdapter: LocationAdapter {
    var authorization: LocationAuthorization = .authorized
    var onEvent: (@MainActor (LocationAdapterEvent) -> Void)?
    private(set) var locationRequestCount = 0

    func requestAuthorization() {}

    func requestLocation() {
        locationRequestCount += 1
    }
}

@MainActor
private final class RecordingLocationAdapter: LocationAdapter {
    var authorization: LocationAuthorization
    var onEvent: (@MainActor (LocationAdapterEvent) -> Void)?
    var coordinate: GeoCoordinate?
    var recordedAt: Date
    private(set) var authorizationRequestCount = 0
    private(set) var locationRequestCount = 0

    init(
        authorization: LocationAuthorization,
        coordinate: GeoCoordinate?,
        recordedAt: Date = .now
    ) {
        self.authorization = authorization
        self.coordinate = coordinate
        self.recordedAt = recordedAt
    }

    func requestAuthorization() {
        authorizationRequestCount += 1
        authorization = .authorized
        onEvent?(.authorizationChanged(.authorized))
    }

    func requestLocation() {
        locationRequestCount += 1
        guard authorization == .authorized, let coordinate else {
            onEvent?(.failed(authorization))
            return
        }
        onEvent?(.located(LocationSample(
            coordinate: coordinate,
            horizontalAccuracy: nil,
            recordedAt: recordedAt
        )))
    }

    func startUpdatingLocation(allowsBackgroundUpdates _: Bool) {
        guard authorization == .authorized, let coordinate else {
            onEvent?(.failed(authorization))
            return
        }
        onEvent?(.updated(LocationSample(
            coordinate: coordinate,
            horizontalAccuracy: nil,
            recordedAt: recordedAt
        )))
    }

    func emit(_ event: LocationAdapterEvent) {
        onEvent?(event)
    }
}

private final class TestClock: @unchecked Sendable {
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
