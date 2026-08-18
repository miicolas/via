import Foundation

extension InMemoryDeparturesRepository {
    static let stationsPreview = Self(board: .stationsPreview)
}

extension DepartureBoard {
    static let stationsPreview: Self = {
        let area = StationsArea.mapPreview
        let routesByID = Dictionary(uniqueKeysWithValues: area.routes.map { ($0.id, $0) })
        let station = area.stations.first { $0.id == StationID(rawValue: "preview:chatelet") }
        let now = Date.now
        let destinations = [
            "La Défense",
            "Bagneux",
            "Villejuif",
            "Mairie des Lilas",
            "Olympiades",
            "Cergy–Le Haut",
            "Aéroport Charles-de-Gaulle 2",
            "Melun",
        ]

        let groups = (station?.routeIDs ?? [])
            .prefix(destinations.count)
            .enumerated()
            .compactMap { index, routeID -> DepartureGroup? in
                guard let route = routesByID[routeID] else { return nil }
                let firstDeparture = now.addingTimeInterval(Double(index + 1) * 4 * 60)
                return DepartureGroup(
                    route: route,
                    destination: destinations[index],
                    departures: [
                        firstDeparture,
                        firstDeparture.addingTimeInterval(7 * 60),
                        firstDeparture.addingTimeInterval(14 * 60),
                    ]
                )
            }

        return Self(source: .realtime, generatedAt: now, groups: groups)
    }()
}
