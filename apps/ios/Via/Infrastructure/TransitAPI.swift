import Foundation

enum TransitAPIError: Error, Equatable, LocalizedError, Sendable {
    case invalidURL
    case offline
    case timeout
    case unauthorized
    case rateLimited
    case server(statusCode: Int)
    case decoding
    case contractViolation
    case cancelled

    var errorDescription: String? {
        switch self {
        case .invalidURL: "L’adresse de l’API est invalide."
        case .offline: "Le réseau est indisponible."
        case .timeout: "Le serveur met trop de temps à répondre."
        case .unauthorized: "La session Via n’est plus autorisée."
        case .rateLimited: "Trop de demandes. Réessayez dans un instant."
        case .server: "Le serveur Via est momentanément indisponible."
        case .decoding, .contractViolation: "La réponse du serveur est incompatible."
        case .cancelled: "La demande a été annulée."
        }
    }
}

protocol TransitAPI: Sendable {
    func loadRailMap() async throws -> RailMap
    func loadStations(in bounds: TileBounds) async throws -> StationsInArea
    func search(query: String, near coordinate: GeoCoordinate?) async throws -> SearchResponse
    func loadDepartures(stationID: String) async throws -> DeparturesResponse
}

struct DemoTransitAPI: TransitAPI {
    private let railMap: RailMap
    private let paris = GeoCoordinate(latitude: 48.8566, longitude: 2.3522)

    init() {
        let lineOne = RouteBadge(id: "demo:1", shortName: "1", mode: .metro, color: "FFCD00", textColor: "161A18")
        let lineFour = RouteBadge(id: "demo:4", shortName: "4", mode: .metro, color: "6D1E91", textColor: "FFFFFF")
        let stations = [
            NetworkStation(
                id: "demo:chatelet",
                name: "Châtelet",
                coordinate: GeoCoordinate(latitude: 48.8584, longitude: 2.3470),
                routeIds: [lineOne.id, lineFour.id]
            ),
            NetworkStation(
                id: "demo:louvre",
                name: "Louvre–Rivoli",
                coordinate: GeoCoordinate(latitude: 48.8607, longitude: 2.3376),
                routeIds: [lineOne.id]
            ),
            NetworkStation(
                id: "demo:bastille",
                name: "Bastille",
                coordinate: GeoCoordinate(latitude: 48.8533, longitude: 2.3692),
                routeIds: [lineOne.id]
            ),
            NetworkStation(
                id: "demo:republique",
                name: "République",
                coordinate: GeoCoordinate(latitude: 48.8675, longitude: 2.3630),
                routeIds: [lineOne.id, lineFour.id]
            ),
        ]

        let routeOne = NetworkRoute(
            id: lineOne.id,
            shortName: lineOne.shortName,
            mode: lineOne.mode,
            color: lineOne.color,
            textColor: lineOne.textColor,
            segments: [
                NetworkSegment(
                    id: "demo:1:west-east",
                    coordinates: [
                        GeoCoordinate(latitude: 48.8607, longitude: 2.3376),
                        GeoCoordinate(latitude: 48.8584, longitude: 2.3470),
                        GeoCoordinate(latitude: 48.8533, longitude: 2.3692),
                    ]
                )
            ]
        )
        let routeFour = NetworkRoute(
            id: lineFour.id,
            shortName: lineFour.shortName,
            mode: lineFour.mode,
            color: lineFour.color,
            textColor: lineFour.textColor,
            segments: [
                NetworkSegment(
                    id: "demo:4:north-south",
                    coordinates: [
                        GeoCoordinate(latitude: 48.8750, longitude: 2.3500),
                        GeoCoordinate(latitude: 48.8584, longitude: 2.3470),
                        GeoCoordinate(latitude: 48.8420, longitude: 2.3500),
                    ]
                )
            ]
        )

        railMap = RailMap(routes: [routeOne, routeFour], stations: stations)
        _ = paris
    }

    func loadRailMap() async throws -> RailMap {
        try await Task.sleep(for: .milliseconds(180))
        return railMap
    }

    func loadStations(in bounds: TileBounds) async throws -> StationsInArea {
        let stations = railMap.stations.filter { station in
            station.coordinate.latitude >= bounds.minLatitude &&
                station.coordinate.latitude <= bounds.maxLatitude &&
                station.coordinate.longitude >= bounds.minLongitude &&
                station.coordinate.longitude <= bounds.maxLongitude
        }
        return StationsInArea(stations: stations, routes: [])
    }

    func search(query: String, near coordinate: GeoCoordinate?) async throws -> SearchResponse {
        let normalized = query.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        let lineOne = RouteBadge(id: "demo:1", shortName: "1", mode: .metro, color: "FFCD00", textColor: "161A18")
        let lineFour = RouteBadge(id: "demo:4", shortName: "4", mode: .metro, color: "6D1E91", textColor: "FFFFFF")
        let results = railMap.stations.compactMap { station -> SearchResult? in
            guard station.name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
                .contains(normalized) else { return nil }

            let routes = station.routeIds.compactMap { id in
                id == lineOne.id ? lineOne : id == lineFour.id ? lineFour : nil
            }
            let distance = coordinate.map { station.coordinate.distance(to: $0) }
            return .station(
                StationSearchResult(
                    id: station.id,
                    name: station.name,
                    coordinate: station.coordinate,
                    routes: routes,
                    distanceMeters: distance
                )
            )
        }
        return SearchResponse(results: results, sources: .init(ban: .unavailable))
    }

    func loadDepartures(stationID: String) async throws -> DeparturesResponse {
        guard let station = railMap.stations.first(where: { $0.id == stationID }) else {
            throw TransitAPIError.server(statusCode: 404)
        }
        let now = Date()
        let routeID = station.routeIds.first ?? "demo:1"
        let route = railMap.routes.first(where: { $0.id == routeID }).map {
            RouteBadge(id: $0.id, shortName: $0.shortName, mode: $0.mode, color: $0.color, textColor: $0.textColor)
        } ?? RouteBadge(id: "demo:1", shortName: "1", mode: .metro, color: "FFCD00", textColor: "161A18")
        let times = stride(from: 3, through: 18, by: 5).map { now.addingTimeInterval(Double($0 * 60)) }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return DeparturesResponse(
            source: .realtime,
            generatedAt: formatter.string(from: now),
            groups: [
                DepartureGroup(
                    route: route,
                    destination: station.name == "Bastille" ? "La Défense" : "Château de Vincennes",
                    departures: times.map(formatter.string(from:))
                )
            ]
        )
    }
}
