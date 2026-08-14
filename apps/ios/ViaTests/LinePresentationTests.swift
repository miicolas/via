import Testing
@testable import Via

struct LinePresentationTests {
    @Test
    func stationsOnRouteKeepsOnlyServingStations() {
        let route = NetworkRoute(
            id: "route-1",
            shortName: "1",
            mode: .metro,
            color: "FFCD00",
            textColor: "161A18",
            segments: []
        )
        let stations = [
            NetworkStation(
                id: "station-1",
                name: "Châtelet",
                coordinate: GeoCoordinate(latitude: 48.8584, longitude: 2.3470),
                routeIds: [route.id]
            ),
            NetworkStation(
                id: "station-4",
                name: "Gare du Nord",
                coordinate: GeoCoordinate(latitude: 48.8809, longitude: 2.3553),
                routeIds: ["route-4"]
            ),
        ]

        #expect(stationsOnRoute(route, from: stations).map(\.id) == ["station-1"])
    }

    @Test
    func routeBadgePreservesNetworkStyling() {
        let route = NetworkRoute(
            id: "route-r",
            shortName: "R",
            mode: .rer,
            color: "00A88F",
            textColor: "FFFFFF",
            segments: []
        )

        #expect(route.badge == RouteBadge(
            id: "route-r",
            shortName: "R",
            mode: .rer,
            color: "00A88F",
            textColor: "FFFFFF"
        ))
    }
}
