import XCTest
@testable import Via

@MainActor
final class FavoriteRoutesModelTests: XCTestCase {
    func testResolvesTheRoutesServingASavedStation() async {
        let model = FavoriteRoutesModel(networkRepository: InMemoryNetworkRepository(area: area))

        await model.load(for: [favorite(of: chatelet)])

        XCTAssertEqual(
            model.routes(for: favorite(of: chatelet)).map(\.shortName),
            ["1", "4", "A"]
        )
    }

    func testFallsBackToTheMatchingNameWhenTheIdentifierChanged() async {
        let model = FavoriteRoutesModel(networkRepository: InMemoryNetworkRepository(area: area))
        let renamed = FavoriteStation(
            stationID: "legacy:chatelet",
            name: "Châtelet",
            coordinate: chatelet.coordinate,
            savedAt: .now,
            updatedAt: .now
        )

        await model.load(for: [renamed])

        XCTAssertEqual(model.routes(for: renamed).map(\.shortName), ["1", "4", "A"])
    }

    func testAFavoriteWithoutCoordinateStaysUnresolved() async {
        let model = FavoriteRoutesModel(networkRepository: InMemoryNetworkRepository(area: area))
        let withoutCoordinate = FavoriteStation(
            stationID: chatelet.id.rawValue,
            name: chatelet.name,
            savedAt: .now,
            updatedAt: .now
        )

        await model.load(for: [withoutCoordinate])

        XCTAssertNil(model.routesByStationID[withoutCoordinate.stationID])
    }

    func testAStationMissingFromTheAreaResolvesToNoRoutes() async {
        let model = FavoriteRoutesModel(networkRepository: InMemoryNetworkRepository(area: area))
        let unknown = FavoriteStation(
            stationID: "unknown",
            name: "Inconnue",
            coordinate: GeoCoordinate(latitude: 48.86, longitude: 2.35),
            savedAt: .now,
            updatedAt: .now
        )

        await model.load(for: [unknown])

        XCTAssertEqual(model.routesByStationID[unknown.stationID], [])
    }

    // MARK: - Fixtures

    private let metro1 = RouteBadge(
        id: RouteID(rawValue: "metro:1"),
        shortName: "1",
        mode: .metro,
        colorHex: "#FFCD00",
        textColorHex: "#000000"
    )
    private let metro4 = RouteBadge(
        id: RouteID(rawValue: "metro:4"),
        shortName: "4",
        mode: .metro,
        colorHex: "#B42C91",
        textColorHex: "#FFFFFF"
    )
    private let rerA = RouteBadge(
        id: RouteID(rawValue: "rer:A"),
        shortName: "A",
        mode: .rer,
        colorHex: "#E3051C",
        textColorHex: "#FFFFFF"
    )

    private var chatelet: NetworkStation {
        NetworkStation(
            id: StationID(rawValue: "station:chatelet"),
            name: "Châtelet",
            coordinate: GeoCoordinate(latitude: 48.8583, longitude: 2.3470),
            routeIDs: [rerA.id, metro4.id, metro1.id]
        )
    }

    private var area: StationsArea {
        StationsArea(stations: [chatelet], routes: [metro1, metro4, rerA])
    }

    private func favorite(of station: NetworkStation) -> FavoriteStation {
        FavoriteStation(
            stationID: station.id.rawValue,
            name: station.name,
            coordinate: station.coordinate,
            savedAt: .now,
            updatedAt: .now
        )
    }
}
