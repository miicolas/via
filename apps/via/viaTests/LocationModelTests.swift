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
