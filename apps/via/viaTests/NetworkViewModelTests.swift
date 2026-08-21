import XCTest
@testable import Via

final class NetworkViewModelTests: XCTestCase {
    @MainActor
    func testPreloadPreparesNetworkBeforeFirstViewport() async {
        let repository = NetworkRepositorySpy(
            network: network(),
            area: area()
        )
        let model = NetworkViewModel(repository: repository)

        await model.preload()

        XCTAssertEqual(await repository.railCallCount, 1)

        model.viewportChanged(to: viewport(), phase: .ended)
        await waitUntil { model.state.loading == .loaded }

        XCTAssertEqual(await repository.railCallCount, 1)
        XCTAssertEqual(model.state.snapshot.routes.count, 2)
    }

    @MainActor
    func testInitialEndedViewportLoadsARenderableSnapshot() async {
        let repository = NetworkRepositorySpy(
            network: network(),
            area: area(stationID: "near", latitude: 48.85)
        )
        let model = NetworkViewModel(repository: repository)

        model.viewportChanged(to: viewport(), phase: .ended)

        XCTAssertEqual(model.state.loading, .loading)
        await waitUntil { model.state.loading == .loaded }
        XCTAssertEqual(model.state.snapshot.routes.count, 2)
        XCTAssertEqual(model.state.snapshot.stations.map(\.id), [StationID(rawValue: "near")])
        XCTAssertEqual(model.state.snapshot.lineStyle.opacity, 1)
        let railCalls = await repository.railCallCount
        let viewportCalls = await repository.viewportCallCount
        XCTAssertEqual(railCalls, 1)
        XCTAssertEqual(viewportCalls, 1)
    }

    @MainActor
    func testStationThresholdSkipsViewportLoadingAndHidesAnnotations() async {
        let repository = NetworkRepositorySpy(
            network: network(),
            area: area(stationID: "hidden", latitude: 48.85)
        )
        let model = NetworkViewModel(repository: repository)
        // Past maximumStationSpanMeters (2 100 m): stations neither fetched nor drawn.
        let overview = viewport(spanMeters: 2_500)

        model.viewportChanged(to: overview, phase: .ended)
        await waitUntil { model.state.loading == .loaded }

        XCTAssertTrue(model.state.snapshot.stations.isEmpty)
        XCTAssertEqual(model.state.snapshot.stationOpacity, 0)
        let viewportCalls = await repository.viewportCallCount
        XCTAssertEqual(viewportCalls, 0)
    }

    @MainActor
    func testRoutesArePublishedWhileStationsAreStillLoading() async {
        let repository = NetworkRepositorySpy(
            network: network(),
            area: area(stationID: "near", latitude: 48.85)
        )
        await repository.suspendNextViewport()
        let model = NetworkViewModel(repository: repository)

        model.viewportChanged(to: viewport(), phase: .ended)

        await waitUntil {
            model.state.loading == .loading && model.state.snapshot.routes.count == 2
        }
        XCTAssertTrue(model.state.snapshot.stations.isEmpty)

        await repository.resumeSuspendedViewport()
        await waitUntil { model.state.loading == .loaded }
        XCTAssertEqual(
            model.state.snapshot.stations.map(\.id),
            [StationID(rawValue: "near")]
        )
    }

    @MainActor
    func testContinuousChangeOnlyUpdatesStyleAndFiltersExistingStations() async {
        let repository = NetworkRepositorySpy(
            network: network(),
            area: area(stationID: "near", latitude: 48.85)
        )
        let model = NetworkViewModel(repository: repository)
        model.viewportChanged(to: viewport(), phase: .ended)
        await waitUntil { model.state.loading == .loaded }

        model.viewportChanged(
            to: viewport(centerLatitude: 49.5, spanMeters: 100_000),
            phase: .continuous
        )

        XCTAssertEqual(model.state.snapshot.routes.count, 2)
        XCTAssertTrue(model.state.snapshot.stations.isEmpty)
        XCTAssertEqual(model.state.snapshot.lineStyle.opacity, 0.45, accuracy: 0.000_000_1)
        let viewportCalls = await repository.viewportCallCount
        XCTAssertEqual(viewportCalls, 1)
    }

    @MainActor
    func testContinuousZoomGesturePublishesABoundedNumberOfSnapshots() async {
        let repository = NetworkRepositorySpy(
            network: network(),
            area: area(stationID: "near", latitude: 48.85)
        )
        let model = NetworkViewModel(repository: repository)
        model.viewportChanged(to: viewport(spanMeters: 20_000), phase: .ended)
        await waitUntil { model.state.loading == .loaded }

        // A pinch from 20 km to 62 km of span, one camera update per frame.
        // Every publish rebuilds the whole map content, so the gesture must
        // coalesce into a handful of style steps — not one publish per frame.
        var publishes = 0
        var previous = model.state
        for frame in 1...60 {
            model.viewportChanged(
                to: viewport(spanMeters: 20_000 + Double(frame) * 700),
                phase: .continuous
            )
            if model.state != previous {
                publishes += 1
                previous = model.state
            }
        }

        XCTAssertLessThanOrEqual(publishes, 12)
        XCTAssertGreaterThan(publishes, 0)
    }

    @MainActor
    func testEndedChangeLoadsTheNewViewport() async {
        let repository = NetworkRepositorySpy(
            network: network(),
            area: area(stationID: "first", latitude: 48.85)
        )
        let model = NetworkViewModel(repository: repository)
        model.viewportChanged(to: viewport(), phase: .ended)
        await waitUntil { model.state.loading == .loaded }

        await repository.setArea(area(stationID: "second", latitude: 48.86))
        model.viewportChanged(to: viewport(centerLatitude: 48.86), phase: .continuous)
        let callsDuringGesture = await repository.viewportCallCount
        XCTAssertEqual(callsDuringGesture, 1)

        model.viewportChanged(to: viewport(centerLatitude: 48.86), phase: .ended)
        await waitUntil {
            model.state.loading == .loaded &&
                model.state.snapshot.stations.map(\.id) == [StationID(rawValue: "second")]
        }

        let callsAfterGesture = await repository.viewportCallCount
        XCTAssertEqual(callsAfterGesture, 2)
    }

    @MainActor
    func testResizeRepositionsSharedRouteLanes() async {
        let repository = NetworkRepositorySpy(network: network(), area: area())
        let model = NetworkViewModel(repository: repository)
        model.viewportChanged(to: viewport(height: 400), phase: .ended)
        await waitUntil { model.state.loading == .loaded }
        let firstLatitude = model.state.snapshot.routes[0].segments[0].coordinates[0].latitude

        model.viewportChanged(to: viewport(height: 800), phase: .ended)
        await waitUntil { model.state.loading == .loaded }
        let resizedLatitude = model.state.snapshot.routes[0].segments[0].coordinates[0].latitude

        XCTAssertNotEqual(firstLatitude, resizedLatitude)
    }

    @MainActor
    func testObsoleteViewportResultIsIgnoredAfterCancellation() async {
        let repository = NetworkRepositorySpy(
            network: network(),
            area: area(stationID: "obsolete", latitude: 48.85)
        )
        await repository.suspendNextViewport()
        let model = NetworkViewModel(repository: repository)
        model.viewportChanged(to: viewport(), phase: .ended)
        await waitUntil { await repository.viewportCallCount == 1 }

        await repository.setArea(area(stationID: "current", latitude: 48.86))
        model.viewportChanged(to: viewport(centerLatitude: 48.86), phase: .ended)
        await waitUntil {
            model.state.loading == .loaded &&
                model.state.snapshot.stations.map(\.id) == [StationID(rawValue: "current")]
        }
        await repository.resumeSuspendedViewport()
        try? await Task.sleep(for: .milliseconds(20))

        XCTAssertEqual(
            model.state.snapshot.stations.map(\.id),
            [StationID(rawValue: "current")]
        )
    }

    @MainActor
    func testErrorPreservesThePreviouslyRenderableSnapshot() async {
        let repository = NetworkRepositorySpy(
            network: network(),
            area: area(stationID: "near", latitude: 48.85)
        )
        let model = NetworkViewModel(repository: repository)
        model.viewportChanged(to: viewport(), phase: .ended)
        await waitUntil { model.state.loading == .loaded }

        await repository.setViewportError(.transport)
        model.viewportChanged(to: viewport(centerLatitude: 48.8505), phase: .ended)
        let previousSnapshot = model.state.snapshot
        await waitUntil {
            if case .failed = model.state.loading { return true }
            return false
        }

        XCTAssertEqual(model.state.snapshot, previousSnapshot)
    }

    @MainActor
    private func waitUntil(
        _ predicate: @escaping @MainActor () async -> Bool,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        for _ in 0..<150 {
            if await predicate() { return }
            try? await Task.sleep(for: .milliseconds(10))
        }
        XCTFail("Condition was not met", file: file, line: line)
    }

    private func viewport(
        centerLatitude: Double = 48.85,
        spanMeters: Double = 1_000,
        width: Double = 400,
        height: Double = 800
    ) -> NetworkViewport {
        NetworkViewport(
            center: GeoCoordinate(latitude: centerLatitude, longitude: 2.35),
            latitudeDelta: spanMeters / 111_000,
            longitudeDelta: spanMeters / 111_000,
            width: width,
            height: height
        )
    }

    private func network() -> TransitNetwork {
        let coordinates = [
            GeoCoordinate(latitude: 48.85, longitude: 2.348),
            GeoCoordinate(latitude: 48.85, longitude: 2.352),
        ]
        return TransitNetwork(
            routes: [
                route(id: "A", coordinates: coordinates),
                route(id: "B", coordinates: coordinates),
            ],
            stations: []
        )
    }

    private func route(id: String, coordinates: [GeoCoordinate]) -> NetworkRoute {
        NetworkRoute(
            badge: badge(id),
            segments: [NetworkSegment(id: "\(id)-segment", coordinates: coordinates)]
        )
    }

    private func area(
        stationID: String? = nil,
        latitude: Double = 48.85
    ) -> StationsArea {
        let routes = [badge("A"), badge("B")]
        let stations = stationID.map { stationID in
            [NetworkStation(
                id: StationID(rawValue: stationID),
                name: stationID,
                coordinate: GeoCoordinate(latitude: latitude, longitude: 2.35),
                routeIDs: routes.map(\.id)
            )]
        } ?? []
        return StationsArea(stations: stations, routes: routes)
    }

    private func badge(_ id: String) -> RouteBadge {
        RouteBadge(
            id: RouteID(rawValue: id),
            shortName: id,
            mode: .metro,
            colorHex: "000000",
            textColorHex: "FFFFFF"
        )
    }
}

private actor NetworkRepositorySpy: NetworkRepository {
    private let network: TransitNetwork
    private var area: StationsArea
    private var viewportError: ViaError?
    private var shouldSuspendNextViewport = false
    private var suspendedContinuation: CheckedContinuation<Void, Never>?
    private(set) var railCallCount = 0
    private(set) var viewportCallCount = 0

    init(network: TransitNetwork, area: StationsArea) {
        self.network = network
        self.area = area
    }

    func railMap() -> TransitNetwork {
        railCallCount += 1
        return network
    }

    func viewport(in bounds: GeoBounds) async throws -> StationsArea {
        viewportCallCount += 1
        let response = area
        let responseError = viewportError
        if shouldSuspendNextViewport {
            shouldSuspendNextViewport = false
            await withCheckedContinuation { suspendedContinuation = $0 }
        }
        if let responseError { throw responseError }
        return response
    }

    func setArea(_ area: StationsArea) {
        self.area = area
    }

    func setViewportError(_ error: ViaError?) {
        viewportError = error
    }

    func suspendNextViewport() {
        shouldSuspendNextViewport = true
    }

    func resumeSuspendedViewport() {
        suspendedContinuation?.resume()
        suspendedContinuation = nil
    }
}
