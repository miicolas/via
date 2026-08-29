import Foundation

struct InMemoryNetworkRepository: NetworkRepository {
    var network: TransitNetwork = .init(routes: [], stations: [])
    var area: StationsArea = .init(stations: [], routes: [])
    var bikeArea: BikeStationsArea = .init()
    var sharedMobilityArea: SharedMobilityArea = .init()

    func railMap() async throws -> TransitNetwork { network }
    func viewport(in bounds: GeoBounds) async throws -> StationsArea { area }
    func bikeStations(in bounds: GeoBounds) async throws -> BikeStationsArea { bikeArea }
    func sharedMobility(in bounds: GeoBounds) async throws -> SharedMobilityArea {
        sharedMobilityArea
    }
}

extension InMemoryNetworkRepository {
    static let mapPreview = InMemoryNetworkRepository(
        area: .mapPreview,
        bikeArea: .mapPreview,
        sharedMobilityArea: .mapSharedMobilityPreview
    )
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
                    routeIDs: [metro1.id, metro4.id, metro7.id, metro11.id, metro14.id, rerA.id, rerB.id, rerD.id],
                    accessibility: StationAccessibility(
                        condition: .staffAssistance,
                        label: "Avec un agent",
                        comment: "Agent présent aux heures d’ouverture"
                    ),
                    hasElevators: true,
                    toilets: StationToilets(
                        label: "Sanitaires disponibles",
                        detail: "Accès gratuit · Accessible PMR"
                    ),
                    fountains: StationFountains(
                        status: .available,
                        label: "Fontaine d’eau potable à proximité",
                        detail: "Accessible PMR · Remplissage de gourde possible"
                    )
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

extension BikeStationsArea {
    static let mapPreview = BikeStationsArea(stations: [
        BikeStation(
            id: "preview-hotel-de-ville",
            stationCode: "4015",
            name: "Place de l’Hôtel de Ville",
            coordinate: GeoCoordinate(latitude: 48.8567, longitude: 2.3515),
            capacity: 35,
            availability: BikeStationAvailability(
                mechanicalBikes: 8,
                electricBikes: 5,
                docks: 22,
                isInstalled: true,
                isRenting: true,
                isReturning: true,
                lastReportedAt: .now
            )
        )
    ])
}

extension SharedMobilityArea {
    static let mapSharedMobilityPreview = SharedMobilityArea(
        items: [
            .vehicle(SharedMobilityVehicle(
                id: "preview:dott:bicycle",
                provider: .dott,
                mode: .bicycle,
                coordinate: GeoCoordinate(latitude: 48.8572, longitude: 2.3518),
                batteryPercent: 74,
                rangeMeters: 23_000,
                lastReportedAt: .now,
                rentalURL: URL(string: "https://go.ridedott.com/vehicles/preview?platform=ios"),
                operatorURL: URL(string: "https://ridedott.com/")
            )),
            .vehicle(SharedMobilityVehicle(
                id: "preview:yego:scooter",
                provider: .yego,
                mode: .scooter,
                coordinate: GeoCoordinate(latitude: 48.8560, longitude: 2.3480),
                rangeMeters: 18_000,
                lastReportedAt: .now,
                rentalURL: URL(string: "yego://"),
                operatorURL: URL(string: "https://www.rideyego.com/")
            )),
            .station(SharedMobilityStation(
                station: BikeStation(
                    id: "preview:velib:station",
                    stationCode: "4015",
                    name: "Place de l’Hôtel de Ville",
                    coordinate: GeoCoordinate(latitude: 48.8567, longitude: 2.3515),
                    capacity: 35,
                    availability: BikeStationAvailability(
                        mechanicalBikes: 8,
                        electricBikes: 5,
                        docks: 22,
                        isInstalled: true,
                        isRenting: true,
                        isReturning: true,
                        lastReportedAt: .now
                    )
                ),
                operatorURL: URL(string: "https://www.velib-metropole.fr/")
            )),
        ],
        sources: Dictionary(uniqueKeysWithValues: SharedMobilityProvider.allCases.map {
            ($0, SharedMobilitySourceStatus(state: .ok, sourceUpdatedAt: .now))
        })
    )
}
