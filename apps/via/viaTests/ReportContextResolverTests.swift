import XCTest
@testable import Via

@MainActor
final class ReportContextResolverTests: XCTestCase {
    func testAutomaticResolutionChoosesTheNearestStation() async {
        let coordinate = GeoCoordinate(latitude: 48.8566, longitude: 2.3522)
        let route = sampleRoute
        let nearest = NetworkStation(
            id: StationID(rawValue: "nearest"),
            name: "La plus proche",
            coordinate: GeoCoordinate(latitude: 48.8567, longitude: 2.3522),
            routeIDs: [route.id]
        )
        let farther = NetworkStation(
            id: StationID(rawValue: "farther"),
            name: "La plus éloignée",
            coordinate: GeoCoordinate(latitude: 48.8666, longitude: 2.3522),
            routeIDs: [route.id]
        )
        let resolver = makeResolver(
            coordinate: coordinate,
            area: StationsArea(stations: [farther, nearest], routes: [route])
        )

        resolver.loadIfNeeded()
        await waitForState(resolver) { $0.selection != nil }

        let selection = resolver.state.selection
        XCTAssertEqual(selection?.station.id, nearest.id)
        XCTAssertEqual(selection?.source, .automatic)
        XCTAssertEqual(selection?.coordinate, coordinate)
    }

    func testManualStationReplacesTheAutomaticStationButKeepsCurrentCoordinate() async {
        let coordinate = GeoCoordinate(latitude: 48.8566, longitude: 2.3522)
        let resolver = makeResolver(coordinate: coordinate)

        resolver.loadIfNeeded()
        await waitForState(resolver) { $0.selection != nil }
        resolver.selectManualStation(manualStation)

        let selection = resolver.state.selection
        XCTAssertEqual(selection?.station.id, manualStation.id)
        XCTAssertEqual(selection?.source, .manual)
        XCTAssertEqual(selection?.coordinate, coordinate)
    }

    func testManualStationWorksWithoutLocationAndUsesTheStationCoordinate() async {
        let location = LocationModel(adapter: InMemoryLocationAdapter(
            authorization: .denied,
            coordinate: nil
        ))
        let resolver = ReportContextResolver(
            locationModel: location,
            networkRepository: InMemoryNetworkRepository(area: .init(stations: [], routes: []))
        )

        resolver.loadIfNeeded()
        await waitForState(resolver) {
            if case .unavailable(.denied) = $0 { return true }
            return false
        }
        resolver.selectManualStation(manualStation)

        XCTAssertEqual(resolver.state.selection?.coordinate, manualStation.coordinate)
        XCTAssertEqual(resolver.state.selection?.source, .manual)
    }

    func testDeniedLocationExposesUnavailableState() async {
        let location = LocationModel(adapter: InMemoryLocationAdapter(
            authorization: .denied,
            coordinate: nil
        ))
        let resolver = ReportContextResolver(
            locationModel: location,
            networkRepository: InMemoryNetworkRepository(area: .init(stations: [], routes: []))
        )

        resolver.loadIfNeeded()
        await waitForState(resolver) {
            if case .unavailable(.denied) = $0 { return true }
            return false
        }

        XCTAssertEqual(resolver.state, .unavailable(.denied))
    }

    func testEmptyViewportExposesEmptyState() async {
        let resolver = makeResolver(
            area: StationsArea(stations: [], routes: [])
        )

        resolver.loadIfNeeded()
        await waitForState(resolver) { $0 == .empty }

        XCTAssertEqual(resolver.state, .empty)
    }

    func testNetworkFailureExposesErrorState() async {
        let location = LocationModel(adapter: InMemoryLocationAdapter())
        let resolver = ReportContextResolver(
            locationModel: location,
            networkRepository: FailingReportNetworkRepository(error: .unavailable)
        )

        resolver.loadIfNeeded()
        await waitForState(resolver) { $0 == .error(.unavailable) }

        XCTAssertEqual(resolver.state, .error(.unavailable))
    }

    private var sampleRoute: RouteBadge {
        RouteBadge(
            id: RouteID(rawValue: "metro:1"),
            shortName: "1",
            mode: .metro,
            colorHex: "#FFCD00",
            textColorHex: "#000000"
        )
    }

    private var manualStation: StationSearchResult {
        StationSearchResult(
            id: StationID(rawValue: "manual"),
            name: "Station choisie",
            coordinate: GeoCoordinate(latitude: 48.9, longitude: 2.4),
            routes: [sampleRoute],
            distanceMeters: nil
        )
    }

    private func makeResolver(
        coordinate: GeoCoordinate = GeoCoordinate(latitude: 48.8566, longitude: 2.3522),
        area: StationsArea? = nil
    ) -> ReportContextResolver {
        let route = sampleRoute
        let defaultStation = NetworkStation(
            id: StationID(rawValue: "automatic"),
            name: "Station automatique",
            coordinate: GeoCoordinate(latitude: 48.8567, longitude: 2.3522),
            routeIDs: [route.id]
        )
        return ReportContextResolver(
            locationModel: LocationModel(adapter: InMemoryLocationAdapter(coordinate: coordinate)),
            networkRepository: InMemoryNetworkRepository(
                area: area ?? StationsArea(stations: [defaultStation], routes: [route])
            )
        )
    }

    private func waitForState(
        _ resolver: ReportContextResolver,
        matching predicate: (ReportContextResolutionState) -> Bool
    ) async {
        for _ in 0..<100 {
            if predicate(resolver.state) { return }
            try? await Task.sleep(for: .milliseconds(5))
        }
        XCTFail("Timed out waiting for report context state, got \(resolver.state)")
    }
}

private struct FailingReportNetworkRepository: NetworkRepository {
    let error: ViaError

    func railMap() async throws -> TransitNetwork {
        throw error
    }

    func viewport(in bounds: GeoBounds) async throws -> StationsArea {
        throw error
    }

    func bikeStations(in bounds: GeoBounds) async throws -> BikeStationsArea {
        throw error
    }
}
