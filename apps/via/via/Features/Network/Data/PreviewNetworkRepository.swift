struct InMemoryNetworkRepository: NetworkRepository {
    var network: TransitNetwork = .init(routes: [], stations: [])
    var area: StationsArea = .init(stations: [], routes: [])

    func railMap() async throws -> TransitNetwork { network }
    func viewport(in bounds: GeoBounds) async throws -> StationsArea { area }
}

extension InMemoryNetworkRepository {
    static let mapPreview = InMemoryNetworkRepository(area: .mapPreview)
}

extension StationsArea {
    static let mapPreview: StationsArea = {
        let metro1 = RouteBadge(
            id: RouteID(rawValue: "preview:metro:1"),
            shortName: "1",
            mode: .metro,
            colorHex: "#FFCD00",
            textColorHex: "#000000"
        )
        let metro4 = RouteBadge(
            id: RouteID(rawValue: "preview:metro:4"),
            shortName: "4",
            mode: .metro,
            colorHex: "#B42C91",
            textColorHex: "#FFFFFF"
        )
        let metro7 = RouteBadge(
            id: RouteID(rawValue: "preview:metro:7"),
            shortName: "7",
            mode: .metro,
            colorHex: "#F59EB3",
            textColorHex: "#000000"
        )
        let metro11 = RouteBadge(
            id: RouteID(rawValue: "preview:metro:11"),
            shortName: "11",
            mode: .metro,
            colorHex: "#8D5E2A",
            textColorHex: "#FFFFFF"
        )
        let metro14 = RouteBadge(
            id: RouteID(rawValue: "preview:metro:14"),
            shortName: "14",
            mode: .metro,
            colorHex: "#662483",
            textColorHex: "#FFFFFF"
        )
        let rerA = RouteBadge(
            id: RouteID(rawValue: "preview:rer:A"),
            shortName: "A",
            mode: .rer,
            colorHex: "#E3051C",
            textColorHex: "#FFFFFF"
        )
        let rerB = RouteBadge(
            id: RouteID(rawValue: "preview:rer:B"),
            shortName: "B",
            mode: .rer,
            colorHex: "#5291CE",
            textColorHex: "#FFFFFF"
        )
        let rerD = RouteBadge(
            id: RouteID(rawValue: "preview:rer:D"),
            shortName: "D",
            mode: .rer,
            colorHex: "#00A88F",
            textColorHex: "#FFFFFF"
        )
        let bus67 = RouteBadge(
            id: RouteID(rawValue: "preview:bus:67"),
            shortName: "67",
            mode: .bus,
            colorHex: "#6ECA97",
            textColorHex: "#000000"
        )
        let routes = [metro1, metro4, metro7, metro11, metro14, rerA, rerB, rerD, bus67]

        return StationsArea(
            stations: [
                NetworkStation(
                    id: StationID(rawValue: "preview:hotel-de-ville"),
                    name: "Hôtel de Ville",
                    coordinate: GeoCoordinate(latitude: 48.8575, longitude: 2.3514),
                    routeIDs: [metro1.id, metro11.id, bus67.id]
                ),
                NetworkStation(
                    id: StationID(rawValue: "preview:chatelet"),
                    name: "Châtelet",
                    coordinate: GeoCoordinate(latitude: 48.8583, longitude: 2.3470),
                    routeIDs: [metro1.id, metro4.id, metro7.id, metro11.id, metro14.id, rerA.id, rerB.id, rerD.id]
                ),
                NetworkStation(
                    id: StationID(rawValue: "preview:cite"),
                    name: "Cité",
                    coordinate: GeoCoordinate(latitude: 48.8554, longitude: 2.3471),
                    routeIDs: [metro4.id]
                ),
                NetworkStation(
                    id: StationID(rawValue: "preview:pont-marie"),
                    name: "Pont Marie",
                    coordinate: GeoCoordinate(latitude: 48.8536, longitude: 2.3570),
                    routeIDs: [metro7.id]
                ),
            ],
            routes: routes
        )
    }()
}
