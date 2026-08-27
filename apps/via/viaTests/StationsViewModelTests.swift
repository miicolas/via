import XCTest
@testable import Via

final class StationsViewModelTests: XCTestCase {
    func testRealtimeEstimateWithoutBaselineUsesLiveColorRole() {
        XCTAssertEqual(
            departureTimeColorRole(status: .noReport, source: .realtime),
            .live
        )
    }

    func testTheoreticalScheduleKeepsTheoreticalColorRole() {
        XCTAssertEqual(
            departureTimeColorRole(status: .scheduled, source: .theoretical),
            .theoretical
        )
    }

    func testScheduledRemainderStaysTheoreticalInAMixedRealtimeBoard() {
        XCTAssertEqual(
            departureTimeColorRole(status: .scheduled, source: .realtime),
            .theoretical
        )
    }

    func testDepartureCountdownRoundsUpToTheNextWholeMinute() {
        let now = Date(timeIntervalSince1970: 1_000_000)

        XCTAssertEqual(
            DepartureTimingMath.minutesUntil(now.addingTimeInterval(121), now: now),
            3
        )
        XCTAssertEqual(
            DepartureTimingMath.minutesUntil(now.addingTimeInterval(-1), now: now),
            0
        )
    }

    func testDepartureDelayUsesReadableWholeMinutes() {
        XCTAssertEqual(DepartureTimingMath.roundedDelayMinutes(30), 1)
        XCTAssertEqual(DepartureTimingMath.roundedDelayMinutes(330), 6)
        XCTAssertEqual(DepartureTimingMath.roundedDelayMinutes(-120), 2)
    }

    func testNearestStationUsesGeodesicDistanceAndResolvesRoutes() {
        let location = GeoCoordinate(latitude: 48.8566, longitude: 2.3522)
        let nearestRoute = route(id: "nearest", shortName: "1", mode: .metro)
        let fartherRoute = route(id: "farther", shortName: "A", mode: .rer)
        let area = StationsArea(
            stations: [
                NetworkStation(
                    id: StationID(rawValue: "farther-station"),
                    name: "Farther",
                    coordinate: GeoCoordinate(latitude: 48.8700, longitude: 2.3522),
                    routeIDs: [fartherRoute.id]
                ),
                NetworkStation(
                    id: StationID(rawValue: "nearest-station"),
                    name: "Nearest",
                    coordinate: GeoCoordinate(latitude: 48.8570, longitude: 2.3522),
                    routeIDs: [nearestRoute.id]
                ),
            ],
            routes: [fartherRoute, nearestRoute]
        )

        let candidate = StationOverviewBuilder.nearestStation(in: area, to: location)

        XCTAssertEqual(candidate?.station.id, StationID(rawValue: "nearest-station"))
        XCTAssertEqual(candidate?.routes, [nearestRoute])
        XCTAssertLessThan(candidate?.distanceMeters ?? .greatestFiniteMagnitude, 100)
    }

    func testOverviewCarriesStationToiletsIntoTheDetailModel() {
        let route = route(id: "metro-14", shortName: "14", mode: .metro)
        let toilets = StationToilets(
            label: "Sanitaires disponibles",
            detail: "Accès gratuit · Accessible PMR"
        )
        let candidate = StationCandidate(
            station: NetworkStation(
                id: StationID(rawValue: "station"),
                name: "Station",
                coordinate: GeoCoordinate(latitude: 48.8566, longitude: 2.3522),
                routeIDs: [route.id],
                toilets: toilets
            ),
            routes: [route],
            distanceMeters: 50
        )

        let overview = StationOverviewBuilder.makeOverview(
            from: candidate,
            board: DepartureBoard(
                source: .unavailable,
                generatedAt: Date(timeIntervalSince1970: 1_000_000),
                groups: []
            ),
            now: Date(timeIntervalSince1970: 1_000_000)
        )

        XCTAssertEqual(overview.toilets, toilets)
    }

    func testNextDeparturesKeepsTheEarliestFutureGroupPerRouteAndDestination() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let routeA = route(id: "a", shortName: "1", mode: .metro)
        let routeB = route(id: "b", shortName: "A", mode: .rer)
        let board = DepartureBoard(
            source: .realtime,
            generatedAt: now,
            groups: [
                DepartureGroup(
                    route: routeA,
                    destination: "Destination tardive",
                    departures: [now.addingTimeInterval(900)]
                ),
                DepartureGroup(
                    route: routeA,
                    destination: "Destination proche",
                    departures: [now.addingTimeInterval(-60), now.addingTimeInterval(300)]
                ),
                DepartureGroup(
                    route: routeB,
                    destination: "Sans passage",
                    departures: [now.addingTimeInterval(-60)]
                ),
            ]
        )

        let departures = StationOverviewBuilder.nextDepartures(
            from: board,
            routes: [routeA, routeB],
            now: now
        )

        XCTAssertEqual(departures.count, 2)
        XCTAssertEqual(departures.map(\.route.id), [routeA.id, routeA.id])
        XCTAssertEqual(
            departures.map(\.destination),
            ["Destination tardive", "Destination proche"]
        )
        XCTAssertEqual(departures[0].departureAt, .some(now.addingTimeInterval(900)))
        XCTAssertEqual(departures[1].departureAt, .some(now.addingTimeInterval(300)))
    }

    func testNextDeparturesPreservesDelayMetadataAndHidesDepartedItems() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let route = route(id: "metro", shortName: "1", mode: .metro)
        let scheduled = now.addingTimeInterval(300)
        let expected = now.addingTimeInterval(480)
        let board = DepartureBoard(
            source: .realtime,
            generatedAt: now,
            fetchedAt: now.addingTimeInterval(-18),
            groups: [
                DepartureGroup(
                    route: route,
                    destination: "La Défense",
                    departureItems: [
                        DepartureItem(
                            id: "departed",
                            scheduledAt: now.addingTimeInterval(120),
                            expectedAt: now.addingTimeInterval(120),
                            delaySeconds: 0,
                            status: .departed
                        ),
                        DepartureItem(
                            id: "delayed",
                            scheduledAt: scheduled,
                            expectedAt: expected,
                            delaySeconds: 180,
                            status: .delayed
                        ),
                    ]
                )
            ]
        )

        let departures = StationOverviewBuilder.nextDepartures(
            from: board,
            routes: [route],
            now: now
        )

        XCTAssertEqual(departures.count, 1)
        XCTAssertEqual(departures.first?.id, "delayed")
        XCTAssertEqual(departures.first?.scheduledAt, scheduled)
        XCTAssertEqual(departures.first?.departureAt, expected)
        XCTAssertEqual(departures.first?.delaySeconds, 180)
        XCTAssertEqual(departures.first?.status, .delayed)
    }

    func testNextDeparturesKeepsCancellationWithoutATimestampVisible() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let route = route(id: "metro", shortName: "1", mode: .metro)
        let board = DepartureBoard(
            source: .realtime,
            generatedAt: now,
            groups: [
                DepartureGroup(
                    route: route,
                    destination: "La Défense",
                    departureItems: [
                        DepartureItem(
                            id: "cancelled",
                            scheduledAt: nil,
                            expectedAt: nil,
                            delaySeconds: nil,
                            status: .cancelled
                        )
                    ]
                )
            ]
        )

        let departures = StationOverviewBuilder.nextDepartures(
            from: board,
            routes: [route],
            now: now
        )

        XCTAssertEqual(departures.first?.status, .cancelled)
        XCTAssertNil(departures.first?.departureAt)
    }

    func testDepartureBoardKeepsEveryUpcomingPassageForTheStationDetail() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let metro = route(id: "metro", shortName: "1", mode: .metro)
        let bus = route(id: "bus", shortName: "38", mode: .bus)
        let board = DepartureBoard(
            source: .realtime,
            generatedAt: now,
            groups: [
                DepartureGroup(
                    route: metro,
                    destination: "La Défense",
                    departureItems: [
                        DepartureItem(
                            id: "metro-first",
                            scheduledAt: now.addingTimeInterval(120),
                            expectedAt: nil,
                            delaySeconds: nil,
                            status: .onTime
                        ),
                        DepartureItem(
                            id: "metro-second",
                            scheduledAt: now.addingTimeInterval(420),
                            expectedAt: nil,
                            delaySeconds: nil,
                            status: .onTime
                        ),
                        DepartureItem(
                            id: "metro-departed",
                            scheduledAt: now.addingTimeInterval(-60),
                            expectedAt: now.addingTimeInterval(-60),
                            delaySeconds: nil,
                            status: .departed
                        ),
                    ]
                ),
                DepartureGroup(
                    route: bus,
                    destination: "Gare du Nord",
                    departureItems: [
                        DepartureItem(
                            id: "bus-first",
                            scheduledAt: now.addingTimeInterval(180),
                            expectedAt: nil,
                            delaySeconds: nil,
                            status: .onTime
                        ),
                        DepartureItem(
                            id: "bus-second",
                            scheduledAt: now.addingTimeInterval(600),
                            expectedAt: nil,
                            delaySeconds: nil,
                            status: .onTime
                        ),
                    ]
                ),
            ]
        )

        let fullBoard = StationOverviewBuilder.departureBoard(
            from: board,
            routes: [metro, bus],
            now: now
        )
        let compactSummary = StationOverviewBuilder.nextDepartures(
            from: board,
            routes: [metro, bus],
            now: now
        )

        XCTAssertEqual(
            fullBoard.map(\.id),
            ["metro-first", "metro-second", "bus-first", "bus-second"]
        )
        XCTAssertEqual(compactSummary.map(\.id), ["metro-first", "bus-first"])
    }

    func testCompactBoardKeepsBothDirectionsOfALineWithOnePassageEach() {
        let now = Date(timeIntervalSince1970: 2_000_000)
        let metro = route(id: "metro-4", shortName: "4", mode: .metro)
        let bus = route(id: "bus", shortName: "38", mode: .bus)
        let board = DepartureBoard(
            source: .realtime,
            generatedAt: now,
            groups: [
                DepartureGroup(
                    route: metro,
                    destination: "Bagneux",
                    departureItems: [
                        DepartureItem(
                            id: "metro-cancelled",
                            scheduledAt: now.addingTimeInterval(120),
                            expectedAt: nil,
                            delaySeconds: nil,
                            status: .cancelled
                        )
                    ]
                ),
                DepartureGroup(
                    route: metro,
                    destination: "Porte de Clignancourt",
                    departureItems: [
                        DepartureItem(
                            id: "metro-other-direction",
                            scheduledAt: now.addingTimeInterval(240),
                            expectedAt: nil,
                            delaySeconds: nil,
                            status: .onTime
                        ),
                        DepartureItem(
                            id: "metro-other-direction-later",
                            scheduledAt: now.addingTimeInterval(480),
                            expectedAt: nil,
                            delaySeconds: nil,
                            status: .onTime
                        ),
                    ]
                ),
                DepartureGroup(
                    route: bus,
                    destination: "Gare du Nord",
                    departures: [now.addingTimeInterval(300)]
                ),
            ]
        )
        let departures = StationOverviewBuilder.nextDepartures(
            from: board,
            routes: [metro, bus],
            now: now
        )

        // Both directions of the metro draw their own row, each on its own next
        // passage and on that one only — the second Clignancourt passage belongs
        // to the line sheet, not to the compact board.
        XCTAssertEqual(
            departures.map(\.destination),
            ["Bagneux", "Porte de Clignancourt", "Gare du Nord"]
        )
        XCTAssertEqual(
            departures.prefix(2).map(\.id),
            ["metro-cancelled", "metro-other-direction"]
        )
    }

    @MainActor
    func testViewModelLoadsNearestStationAndDepartureBoard() async {
        let location = InMemoryLocationAdapter(
            authorization: .authorized,
            coordinate: GeoCoordinate(latitude: 48.8566, longitude: 2.3522)
        )
        let route = route(id: "metro-1", shortName: "1", mode: .metro)
        let station = NetworkStation(
            id: StationID(rawValue: "station"),
            name: "Station",
            coordinate: GeoCoordinate(latitude: 48.8567, longitude: 2.3522),
            routeIDs: [route.id]
        )
        let network = InMemoryNetworkRepository(
            area: StationsArea(stations: [station], routes: [route])
        )
        let now = Date(timeIntervalSince1970: 2_000_000)
        let departures = InMemoryDeparturesRepository(
            board: DepartureBoard(
                source: .theoretical,
                generatedAt: now,
                groups: [
                    DepartureGroup(
                        route: route,
                        destination: "La Défense",
                        departures: [now.addingTimeInterval(240)]
                    )
                ]
            )
        )
        let model = StationsViewModel(
            locationAdapter: location,
            networkRepository: network,
            departuresRepository: departures,
            now: { now }
        )

        model.loadIfNeeded()
        await waitForState(model) { state in
            if case .loaded = state { return true }
            return false
        }

        guard case .loaded(let overview) = model.state else {
            return XCTFail("Expected a loaded station")
        }
        XCTAssertEqual(overview.name, "Station")
        XCTAssertEqual(overview.departureSource, .theoretical)
        XCTAssertEqual(overview.departures.first?.destination, "La Défense")
    }

    @MainActor
    func testViewModelAutomaticallyRefreshesDepartureBoard() async {
        let location = InMemoryLocationAdapter(
            authorization: .authorized,
            coordinate: GeoCoordinate(latitude: 48.8566, longitude: 2.3522)
        )
        let route = route(id: "metro-1", shortName: "1", mode: .metro)
        let station = NetworkStation(
            id: StationID(rawValue: "station"),
            name: "Station",
            coordinate: GeoCoordinate(latitude: 48.8567, longitude: 2.3522),
            routeIDs: [route.id]
        )
        let now = Date(timeIntervalSince1970: 2_000_000)
        let firstDeparture = now.addingTimeInterval(240)
        let updatedDeparture = now.addingTimeInterval(540)
        let departures = ScriptedDeparturesRepository(
            boards: [
                DepartureBoard(
                    source: .realtime,
                    generatedAt: now,
                    groups: [
                        DepartureGroup(
                            route: route,
                            destination: "La Défense",
                            departures: [firstDeparture]
                        )
                    ]
                ),
                DepartureBoard(
                    source: .realtime,
                    generatedAt: now.addingTimeInterval(30),
                    groups: [
                        DepartureGroup(
                            route: route,
                            destination: "La Défense",
                            departures: [updatedDeparture]
                        )
                    ]
                ),
            ]
        )
        let model = StationsViewModel(
            locationAdapter: location,
            networkRepository: InMemoryNetworkRepository(
                area: StationsArea(stations: [station], routes: [route])
            ),
            departuresRepository: departures,
            now: { now }
        )

        model.loadIfNeeded()
        await waitForState(model) { state in
            if case .loaded = state { return true }
            return false
        }

        let automaticRefreshTask = Task { @MainActor in
            await model.runAutomaticRefresh(every: .milliseconds(5))
        }

        for _ in 0..<100 {
            if await departures.requestCount() >= 2,
               model.state.overview?.departures.first?.departureAt == .some(updatedDeparture) {
                break
            }
            try? await Task.sleep(for: .milliseconds(1))
        }

        automaticRefreshTask.cancel()
        await automaticRefreshTask.value

        guard case .loaded(let overview) = model.state else {
            return XCTFail("Expected an automatically refreshed station")
        }
        XCTAssertEqual(overview.departures.first?.departureAt, .some(updatedDeparture))
    }

    @MainActor
    func testViewModelExposesEmptyStateWhenNoStationIsReturned() async {
        let model = StationsViewModel(
            locationAdapter: InMemoryLocationAdapter(),
            networkRepository: InMemoryNetworkRepository(
                area: StationsArea(stations: [], routes: [])
            ),
            departuresRepository: InMemoryDeparturesRepository(),
            now: { Date(timeIntervalSince1970: 2_000_000) }
        )

        model.loadIfNeeded()
        await waitForState(model) { $0 == .empty }

        XCTAssertEqual(model.state, .empty)
    }

    @MainActor
    func testViewModelKeepsStationWhenDeparturesAreUnavailable() async {
        let location = InMemoryLocationAdapter()
        let route = route(id: "metro-1", shortName: "1", mode: .metro)
        let station = NetworkStation(
            id: StationID(rawValue: "station"),
            name: "Station",
            coordinate: GeoCoordinate(latitude: 48.8567, longitude: 2.3522),
            routeIDs: [route.id]
        )
        let model = StationsViewModel(
            locationAdapter: location,
            networkRepository: InMemoryNetworkRepository(
                area: StationsArea(stations: [station], routes: [route])
            ),
            departuresRepository: FailingDeparturesRepository(),
            now: { Date(timeIntervalSince1970: 2_000_000) }
        )

        model.loadIfNeeded()
        await waitForState(model) { state in
            if case .loaded = state { return true }
            return false
        }

        guard case .loaded(let overview) = model.state else {
            return XCTFail("Expected the station to remain visible")
        }
        XCTAssertEqual(overview.departureSource, .unavailable)
        XCTAssertTrue(overview.departures.isEmpty)
    }

    @MainActor
    func testViewModelExposesNetworkErrorAndRetryLoadsAgain() async {
        let route = route(id: "metro-1", shortName: "1", mode: .metro)
        let station = NetworkStation(
            id: StationID(rawValue: "station"),
            name: "Station",
            coordinate: GeoCoordinate(latitude: 48.8567, longitude: 2.3522),
            routeIDs: [route.id]
        )
        let area = StationsArea(stations: [station], routes: [route])
        let network = ScriptedNetworkRepository(results: [.failure(.unavailable)])
        let model = StationsViewModel(
            locationAdapter: InMemoryLocationAdapter(),
            networkRepository: network,
            departuresRepository: InMemoryDeparturesRepository(),
            now: { Date(timeIntervalSince1970: 2_000_000) }
        )

        model.loadIfNeeded()
        await waitForState(model) { state in
            if case .failed(let error, let previous) = state,
               error == .unavailable,
               previous == nil {
                return true
            }
            return false
        }

        await network.append(.success(area))
        model.retry()
        await waitForState(model) { state in
            if case .loaded = state { return true }
            return false
        }

        guard case .loaded(let overview) = model.state else {
            return XCTFail("Expected retry to load the station")
        }
        XCTAssertEqual(overview.id, station.id)
    }

    @MainActor
    func testDeniedLocationShowsLocationUnavailable() {
        let model = StationsViewModel(
            locationAdapter: InMemoryLocationAdapter(authorization: .denied),
            networkRepository: InMemoryNetworkRepository.mapPreview,
            departuresRepository: InMemoryDeparturesRepository.stationsPreview
        )

        model.loadIfNeeded()

        XCTAssertEqual(model.state, .locationUnavailable(.denied))
    }

    private func route(id: String, shortName: String, mode: TransitMode) -> RouteBadge {
        RouteBadge(
            id: RouteID(rawValue: id),
            shortName: shortName,
            mode: mode,
            colorHex: "#000000",
            textColorHex: "#FFFFFF"
        )
    }

    @MainActor
    private func waitForState(
        _ model: StationsViewModel,
        matching predicate: (StationsViewState) -> Bool
    ) async {
        for _ in 0..<50 {
            if predicate(model.state) { return }
            await Task.yield()
        }
    }
}

private struct FailingDeparturesRepository: DeparturesRepository {
    func board(stationID: StationID) async throws -> DepartureBoard {
        throw ViaError.unavailable
    }
}

private actor ScriptedDeparturesRepository: DeparturesRepository {
    private var boards: [DepartureBoard]
    private var requests = 0

    init(boards: [DepartureBoard]) {
        self.boards = boards
    }

    func board(stationID: StationID) async throws -> DepartureBoard {
        requests += 1
        if boards.count > 1 {
            return boards.removeFirst()
        }
        return boards[0]
    }

    func requestCount() -> Int {
        requests
    }
}

private actor ScriptedNetworkRepository: NetworkRepository {
    private var results: [Result<StationsArea, ViaError>]

    init(results: [Result<StationsArea, ViaError>]) {
        self.results = results
    }

    func railMap() async throws -> TransitNetwork {
        TransitNetwork(routes: [], stations: [])
    }

    func bikeStations(in bounds: GeoBounds) async throws -> BikeStationsArea {
        BikeStationsArea()
    }

    func viewport(in bounds: GeoBounds) async throws -> StationsArea {
        guard !results.isEmpty else {
            return StationsArea(stations: [], routes: [])
        }
        return try results.removeFirst().get()
    }

    func append(_ result: Result<StationsArea, ViaError>) {
        results.append(result)
    }
}
