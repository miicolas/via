import Testing
@testable import Via

struct JourneyPresentationTests {
    @Test
    func mergesAdjacentWalkingSectionsAndKeepsTransitBadges() {
        let route = JourneyRoute(
            id: "line-1",
            shortName: "1",
            longName: "La Défense — Vincennes",
            mode: .metro,
            color: "FFCD00",
            textColor: "161A18"
        )
        let origin = JourneyPlace(
            name: "Départ",
            coordinate: GeoCoordinate(latitude: 48.85, longitude: 2.35)
        )
        let station = JourneyPlace(
            name: "Station",
            coordinate: GeoCoordinate(latitude: 48.86, longitude: 2.35)
        )
        let destination = JourneyPlace(
            name: "Arrivée",
            coordinate: GeoCoordinate(latitude: 48.87, longitude: 2.35)
        )
        let journey = Journey(
            id: "journey",
            qualifier: .recommended,
            durationSeconds: 900,
            walkingDurationSeconds: 240,
            transferCount: 0,
            departureAt: "2026-08-15T10:00:00+02:00",
            arrivalAt: "2026-08-15T10:15:00+02:00",
            status: .normal,
            warnings: [],
            sections: [
                JourneySection(
                    type: .walk,
                    durationSeconds: 120,
                    from: origin,
                    to: station,
                    departureAt: nil,
                    arrivalAt: nil,
                    geometry: [],
                    route: nil,
                    direction: nil,
                    platform: nil,
                    stops: []
                ),
                JourneySection(
                    type: .transfer,
                    durationSeconds: 120,
                    from: station,
                    to: station,
                    departureAt: nil,
                    arrivalAt: nil,
                    geometry: [],
                    route: nil,
                    direction: nil,
                    platform: nil,
                    stops: []
                ),
                JourneySection(
                    type: .transit,
                    durationSeconds: 660,
                    from: station,
                    to: destination,
                    departureAt: nil,
                    arrivalAt: nil,
                    geometry: [],
                    route: route,
                    direction: "Vincennes",
                    platform: nil,
                    stops: []
                ),
            ]
        )

        let segments = journeySegments(journey)

        #expect(segments.count == 2)
        #expect(segments[0].kind == .walk)
        #expect(segments[0].minutes == 4)
        #expect(segments[1].route?.shortName == "1")
        #expect(segments[1].minutes == 11)
    }
}
