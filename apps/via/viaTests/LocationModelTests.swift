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
    let coordinate: GeoCoordinate?
    private(set) var authorizationRequestCount = 0
    private(set) var locationRequestCount = 0

    init(authorization: LocationAuthorization, coordinate: GeoCoordinate?) {
        self.authorization = authorization
        self.coordinate = coordinate
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
        onEvent?(.located(coordinate))
    }
}
