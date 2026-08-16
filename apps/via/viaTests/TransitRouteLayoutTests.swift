import XCTest
@testable import Via

final class TransitRouteLayoutTests: XCTestCase {
    private let viewport = TransitMapViewport(
        latitudeDelta: 0.02,
        longitudeDelta: 0.02,
        width: 400,
        height: 800
    )

    func testTwoRoutesUseAdjacentSixPointLanes() {
        let routes = [
            route("A", coordinates: eastWestCoordinates()),
            route("B", coordinates: eastWestCoordinates()),
        ]

        let positioned = TransitRouteLayout(routes: routes).positioned(in: viewport)

        XCTAssertEqual(verticalSeparation(positioned[0], positioned[1]), 6, accuracy: 0.001)
        XCTAssertGreaterThan(midpoint(of: positioned[0]).latitude, 48.85)
        XCTAssertLessThan(midpoint(of: positioned[1]).latitude, 48.85)
    }

    func testThreeRoutesUseStableCenteredLanes() {
        let routes = [
            route("A", coordinates: eastWestCoordinates()),
            route("B", coordinates: eastWestCoordinates()),
            route("C", coordinates: eastWestCoordinates()),
        ]

        let positioned = TransitRouteLayout(routes: routes).positioned(in: viewport)

        XCTAssertEqual(verticalSeparation(positioned[0], positioned[1]), 6, accuracy: 0.001)
        XCTAssertEqual(verticalSeparation(positioned[1], positioned[2]), 6, accuracy: 0.001)
        XCTAssertEqual(midpoint(of: positioned[1]).latitude, 48.85, accuracy: 0.000_000_1)
    }

    func testReversedGeometryKeepsEachRouteOnTheSameStableSide() {
        let forward = eastWestCoordinates()
        let routes = [
            route("A", coordinates: forward),
            route("B", coordinates: forward.reversed()),
        ]

        let positioned = TransitRouteLayout(routes: routes).positioned(in: viewport)

        XCTAssertGreaterThan(midpoint(of: positioned[0]).latitude, 48.85)
        XCTAssertLessThan(midpoint(of: positioned[1]).latitude, 48.85)
        XCTAssertEqual(verticalSeparation(positioned[0], positioned[1]), 6, accuracy: 0.001)
    }

    func testSparseBentSharedCorridorStillUsesSeparateLanes() {
        let sparseTrack = coordinates([
            (48.8500, 2.3500),
            (48.8500, 2.3520),
            (48.8514, 2.3520),
        ])
        let routes = [
            route("A", coordinates: sparseTrack),
            route("B", coordinates: sparseTrack.reversed()),
        ]

        let positioned = TransitRouteLayout(routes: routes).positioned(in: viewport)
        let target = GeoCoordinate(latitude: 48.8500, longitude: 2.3510)
        let first = closestCoordinate(to: target, in: positioned[0])
        let second = closestCoordinate(to: target, in: positioned[1])

        XCTAssertEqual(screenDistance(first, second), 6, accuracy: 0.15)
    }

    func testCrossingRoutesAreNotOffset() {
        let horizontal = route("A", coordinates: eastWestCoordinates())
        let vertical = route(
            "B",
            coordinates: coordinates([
                (48.849, 2.351),
                (48.850, 2.351),
                (48.851, 2.351),
            ])
        )

        let positioned = TransitRouteLayout(routes: [horizontal, vertical])
            .positioned(in: viewport)

        XCTAssertEqual(positioned[0], horizontal)
        XCTAssertEqual(positioned[1], vertical)
    }

    func testCorridorShorterThanEightyMetersIsNotOffset() {
        let coordinates = coordinates([
            (48.85, 2.35),
            (48.85, 2.3507),
        ])
        let routes = [
            route("A", coordinates: coordinates),
            route("B", coordinates: coordinates),
        ]

        let positioned = TransitRouteLayout(routes: routes).positioned(in: viewport)

        XCTAssertEqual(positioned, routes)
    }

    func testIsolatedRouteIsNotOffset() {
        let isolated = route("A", coordinates: eastWestCoordinates())

        let positioned = TransitRouteLayout(routes: [isolated]).positioned(in: viewport)

        XCTAssertEqual(positioned, [isolated])
    }

    private func eastWestCoordinates() -> [GeoCoordinate] {
        coordinates([
            (48.85, 2.35),
            (48.85, 2.3515),
            (48.85, 2.353),
        ])
    }

    private func coordinates(
        _ values: [(latitude: Double, longitude: Double)]
    ) -> [GeoCoordinate] {
        values.map { value in
            GeoCoordinate(latitude: value.latitude, longitude: value.longitude)
        }
    }

    private func route<S: Sequence>(
        _ id: String,
        coordinates: S
    ) -> NetworkRoute where S.Element == GeoCoordinate {
        NetworkRoute(
            badge: RouteBadge(
                id: RouteID(rawValue: id),
                shortName: id,
                mode: .metro,
                colorHex: "000000",
                textColorHex: "FFFFFF"
            ),
            segments: [
                NetworkSegment(id: "\(id)-segment", coordinates: Array(coordinates)),
            ]
        )
    }

    private func midpoint(of route: NetworkRoute) -> GeoCoordinate {
        route.segments[0].coordinates[1]
    }

    private func verticalSeparation(
        _ first: NetworkRoute,
        _ second: NetworkRoute
    ) -> Double {
        abs(midpoint(of: first).latitude - midpoint(of: second).latitude) /
            (viewport.latitudeDelta / viewport.height)
    }

    private func closestCoordinate(
        to target: GeoCoordinate,
        in route: NetworkRoute
    ) -> GeoCoordinate {
        route.segments.flatMap(\.coordinates).min { first, second in
            hypot(
                first.latitude - target.latitude,
                first.longitude - target.longitude
            ) < hypot(
                second.latitude - target.latitude,
                second.longitude - target.longitude
            )
        }!
    }

    private func screenDistance(
        _ first: GeoCoordinate,
        _ second: GeoCoordinate
    ) -> Double {
        hypot(
            (first.longitude - second.longitude) /
                (viewport.longitudeDelta / viewport.width),
            (first.latitude - second.latitude) /
                (viewport.latitudeDelta / viewport.height)
        )
    }
}
