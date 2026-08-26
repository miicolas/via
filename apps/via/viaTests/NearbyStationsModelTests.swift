import XCTest
@testable import Via

final class NearbyStationsModelTests: XCTestCase {
    @MainActor
    func testResultsAreSortedByDistanceToTheAnchor() async {
        let repository = NearbyRepositorySpy(area: area(offsetsInMeters: [900, 200, 500]))
        let model = NearbyStationsModel(repository: repository, filterStore: StationMapFilterStore())

        model.anchorChanged(to: .anchor)
        await waitUntil { model.loading == .loaded }

        XCTAssertEqual(
            model.results.map(\.id.rawValue),
            ["station-200", "station-500", "station-900"]
        )
    }

    @MainActor
    func testStationsBeyondTheRadiusAreDropped() async {
        let repository = NearbyRepositorySpy(
            area: area(offsetsInMeters: [500, NearbyStationsModel.radiusMeters + 400])
        )
        let model = NearbyStationsModel(repository: repository, filterStore: StationMapFilterStore())

        model.anchorChanged(to: .anchor)
        await waitUntil { model.loading == .loaded }

        XCTAssertEqual(model.results.map(\.id.rawValue), ["station-500"])
    }

    @MainActor
    func testIncompleteResultsStayOutOfMapAnnotations() async {
        let offsets = (1...80).map { Double($0) * 20 }
        let repository = NearbyRepositorySpy(area: area(offsetsInMeters: offsets))
        let model = NearbyStationsModel(repository: repository, filterStore: StationMapFilterStore())

        model.anchorChanged(to: .anchor)
        await waitUntil { model.loading == .loaded }

        XCTAssertEqual(model.results.count, NearbyStationsModel.resultLimit)
        XCTAssertEqual(model.matchingResultCount, 80)
        XCTAssertTrue(model.annotationItems.isEmpty)
        XCTAssertEqual(model.matchesBeforeFilter, 80)
    }

    @MainActor
    func testCompleteResultsAllBecomeMapAnnotations() async {
        let offsets = (1...35).map { Double($0) * 20 }
        let repository = NearbyRepositorySpy(area: area(offsetsInMeters: offsets))
        let model = NearbyStationsModel(repository: repository, filterStore: StationMapFilterStore())

        model.anchorChanged(to: .anchor)
        await waitUntil { model.loading == .loaded }

        XCTAssertEqual(model.matchingResultCount, 35)
        XCTAssertEqual(model.annotationItems.count, 35)
    }

    @MainActor
    func testDenseSharedMobilityResultsRemainAvailableForDezoomedClusters() async {
        let store = StationMapFilterStore()
        store.filter.criteria = [.sharedBikes]
        let vehicles = (1...80).map { index in
            SharedMobilityItem.vehicle(SharedMobilityVehicle(
                id: "dott-bike-\(index)",
                provider: .dott,
                mode: .bicycle,
                coordinate: GeoCoordinate.anchor.offset(byMeters: Double(index) * 10)
            ))
        }
        let sources = Dictionary(uniqueKeysWithValues: SharedMobilityProvider.allCases.map {
            ($0, SharedMobilitySourceStatus(state: .ok))
        })
        let repository = NearbyRepositorySpy(area: area(offsetsInMeters: []))
        await repository.setSharedMobilityArea(SharedMobilityArea(items: vehicles, sources: sources))
        let model = NearbyStationsModel(repository: repository, filterStore: store)

        model.anchorChanged(to: .anchor)
        await waitUntil { model.loading == .loaded && model.matchingResultCount == 80 }

        XCTAssertEqual(model.results.count, NearbyStationsModel.resultLimit)
        XCTAssertEqual(model.annotationItems.count, 80)
    }

    @MainActor
    func testFilterNarrowsTheResultsWithoutAnotherRequest() async {
        let store = StationMapFilterStore()
        let repository = NearbyRepositorySpy(
            area: area(offsetsInMeters: [200, 400], toiletsAtIndices: [1])
        )
        let model = NearbyStationsModel(repository: repository, filterStore: store)

        model.anchorChanged(to: .anchor)
        await waitUntil { model.loading == .loaded }
        XCTAssertEqual(model.results.count, 2)

        store.filter.criteria = [.toilets]

        XCTAssertEqual(model.results.map(\.id.rawValue), ["station-400"])
        // The count before filtering is what lets the empty state say "there
        // are stations here, the filter hides them".
        XCTAssertEqual(model.matchesBeforeFilter, 2)
        let calls = await repository.viewportCallCount
        XCTAssertEqual(calls, 1)
    }

    @MainActor
    func testDocksStayOutUntilTheVelibCriterionIsSelected() async {
        let store = StationMapFilterStore()
        let repository = NearbyRepositorySpy(area: area(offsetsInMeters: [300]))
        await repository.setBikeArea(
            BikeStationsArea(stations: [
                BikeStation(
                    id: "1",
                    stationCode: "04001",
                    name: "Hôtel de Ville",
                    coordinate: GeoCoordinate.anchor.offset(byMeters: 100),
                    capacity: 35,
                    availability: nil
                )
            ])
        )
        let model = NearbyStationsModel(repository: repository, filterStore: store)

        model.anchorChanged(to: .anchor)
        await waitUntil { model.loading == .loaded }
        XCTAssertEqual(model.results.count, 1)
        let idleBikeCalls = await repository.bikeCallCount
        XCTAssertEqual(idleBikeCalls, 0)

        store.filter.criteria = [.bikeStations]
        await waitUntil { model.results.count == 1 && model.results[0].item.bikeStation != nil }

        // Only the dock matches: a station with no facility fails a Vélib' filter.
        XCTAssertEqual(model.results.map(\.item.name), ["Hôtel de Ville"])
    }

    @MainActor
    func testAShortHopReordersWithoutRefetchingAndALongOneRefetches() async {
        let repository = NearbyRepositorySpy(area: area(offsetsInMeters: [200, 600]))
        let model = NearbyStationsModel(repository: repository, filterStore: StationMapFilterStore())

        model.anchorChanged(to: .anchor)
        await waitUntil { model.loading == .loaded }
        XCTAssertEqual(model.results.map(\.id.rawValue), ["station-200", "station-600"])

        // Under the shift threshold: re-sorted from what is already held.
        model.anchorChanged(
            to: .anchor.offset(byMeters: NearbyStationsModel.minimumAnchorShiftMeters - 50)
        )
        var calls = await repository.viewportCallCount
        XCTAssertEqual(calls, 1)
        XCTAssertEqual(model.results.map(\.id.rawValue), ["station-200", "station-600"])

        model.anchorChanged(
            to: .anchor.offset(byMeters: NearbyStationsModel.minimumAnchorShiftMeters + 400)
        )
        await waitUntil { await repository.viewportCallCount == 2 }
        calls = await repository.viewportCallCount
        XCTAssertEqual(calls, 2)
    }

    @MainActor
    func testHeroSkipsDocksBecauseTheyCarryNoDepartureBoard() async {
        let store = StationMapFilterStore()
        store.filter.criteria = [.bikeStations]
        let repository = NearbyRepositorySpy(area: area(offsetsInMeters: [800]))
        await repository.setBikeArea(
            BikeStationsArea(stations: [
                BikeStation(
                    id: "1",
                    stationCode: nil,
                    name: "Dock",
                    coordinate: GeoCoordinate.anchor.offset(byMeters: 100),
                    capacity: 20,
                    availability: nil
                )
            ])
        )
        let model = NearbyStationsModel(repository: repository, filterStore: store)

        model.anchorChanged(to: .anchor)
        await waitUntil { model.results.count == 1 }

        XCTAssertEqual(model.results.first?.item.name, "Dock")
        // The nearest result is a dock, so the tab has no hero to board.
        XCTAssertNil(model.heroStation)
    }

    @MainActor
    func testResultsBoundsCoverEveryResult() async {
        let repository = NearbyRepositorySpy(area: area(offsetsInMeters: [200, 900]))
        let model = NearbyStationsModel(repository: repository, filterStore: StationMapFilterStore())

        model.anchorChanged(to: .anchor)
        await waitUntil { model.loading == .loaded }

        guard let bounds = model.resultsBounds else {
            return XCTFail("Results were expected to have bounds")
        }
        for station in model.results {
            XCTAssertTrue(bounds.contains(station.item.coordinate))
        }
    }

    // MARK: - Helpers

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

    private func area(
        offsetsInMeters: [Double],
        toiletsAtIndices: Set<Int> = []
    ) -> StationsArea {
        let route = RouteBadge(
            id: RouteID(rawValue: "A"),
            shortName: "A",
            mode: .metro,
            colorHex: "000000",
            textColorHex: "FFFFFF"
        )
        let stations = offsetsInMeters.enumerated().map { index, offset in
            NetworkStation(
                id: StationID(rawValue: "station-\(Int(offset))"),
                name: "Station \(Int(offset))",
                coordinate: GeoCoordinate.anchor.offset(byMeters: offset),
                routeIDs: [route.id],
                toilets: toiletsAtIndices.contains(index)
                    ? StationToilets(label: "Sanitaires disponibles", detail: nil)
                    : nil
            )
        }
        return StationsArea(stations: stations, routes: [route])
    }
}

extension GeoCoordinate {
    static let anchor = GeoCoordinate(latitude: 48.85, longitude: 2.35)

    /// Due north, so the offset is a plain latitude shift.
    func offset(byMeters meters: Double) -> GeoCoordinate {
        GeoCoordinate(latitude: latitude + meters / 111_000, longitude: longitude)
    }
}

private actor NearbyRepositorySpy: NetworkRepository {
    private var area: StationsArea
    private var bikeArea = BikeStationsArea()
    private var sharedMobilityArea = SharedMobilityArea()
    private(set) var viewportCallCount = 0
    private(set) var bikeCallCount = 0

    init(area: StationsArea) {
        self.area = area
    }

    func railMap() async throws -> TransitNetwork {
        TransitNetwork(routes: [], stations: [])
    }

    func viewport(in bounds: GeoBounds) async throws -> StationsArea {
        viewportCallCount += 1
        return area
    }

    func bikeStations(in bounds: GeoBounds) async throws -> BikeStationsArea {
        bikeCallCount += 1
        return bikeArea
    }

    func sharedMobility(in bounds: GeoBounds) async throws -> SharedMobilityArea {
        sharedMobilityArea
    }

    func setBikeArea(_ bikeArea: BikeStationsArea) {
        self.bikeArea = bikeArea
    }

    func setSharedMobilityArea(_ sharedMobilityArea: SharedMobilityArea) {
        self.sharedMobilityArea = sharedMobilityArea
    }
}
