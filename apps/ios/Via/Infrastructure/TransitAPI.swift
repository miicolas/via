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

extension TransitAPIError {
    static func from(_ error: Error) -> TransitAPIError {
        if let error = error as? TransitAPIError { return error }
        if error is CancellationError { return .cancelled }
        if let error = error as? URLError {
            switch error.code {
            case .cancelled: return .cancelled
            case .timedOut: return .timeout
            case .notConnectedToInternet, .networkConnectionLost, .cannotFindHost, .cannotConnectToHost:
                return .offline
            default: return .server(statusCode: 0)
            }
        }
        return .server(statusCode: 0)
    }

    static func from(statusCode: Int) -> TransitAPIError {
        switch statusCode {
        case 401, 403: .unauthorized
        case 429: .rateLimited
        default: .server(statusCode: statusCode)
        }
    }

    var logLabel: String {
        switch self {
        case .invalidURL: "invalid_url"
        case .offline: "offline"
        case .timeout: "timeout"
        case .unauthorized: "unauthorized"
        case .rateLimited: "rate_limited"
        case .server(let statusCode): "server_\(statusCode)"
        case .decoding: "decoding"
        case .contractViolation: "contract_violation"
        case .cancelled: "cancelled"
        }
    }
}

protocol TransitAPI: Sendable {
    func loadRailMap() async throws -> RailMap
    func loadStations(in bounds: TileBounds) async throws -> StationsInArea
    func search(query: String, near coordinate: GeoCoordinate?) async throws -> SearchResponse
    func loadDepartures(stationID: String) async throws -> DeparturesResponse
    func planJourneys(_ request: JourneyRequest) async throws -> JourneysResponse
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

    func planJourneys(_ request: JourneyRequest) async throws -> JourneysResponse {
        try await Task.sleep(for: .milliseconds(220))

        let generatedAt = Date()
        let chatelet = railMap.stations.first(where: { $0.id == "demo:chatelet" })!
        let route = railMap.routes.first(where: { $0.id == "demo:1" })!
        let journeyRoute = JourneyRoute(
            id: route.id,
            shortName: route.shortName,
            longName: "La Défense — Château de Vincennes",
            mode: route.mode,
            color: route.color,
            textColor: route.textColor
        )
        let destination = JourneyPlace(name: request.destination.name, coordinate: request.destination.coordinate)
        let origin = JourneyPlace(name: "Votre position", coordinate: request.origin)
        let walkToChateletSeconds = max(60, Int(request.origin.distance(to: chatelet.coordinate) / 1.25))
        let transitSeconds = request.destination.id == chatelet.id
            ? 0
            : max(8 * 60, Int(chatelet.coordinate.distance(to: request.destination.coordinate) / 8.0))
        let departure = generatedAt.addingTimeInterval(4 * 60)

        let primary: Journey
        if request.destination.id == chatelet.id {
            primary = walkingJourney(
                id: "demo:walk:\(request.destination.id)",
                qualifier: .walking,
                origin: origin,
                destination: destination,
                start: departure,
                seconds: walkToChateletSeconds
            )
        } else {
            let walkArrival = departure.addingTimeInterval(Double(walkToChateletSeconds))
            let arrival = walkArrival.addingTimeInterval(Double(transitSeconds))
            primary = Journey(
                id: "demo:metro:\(request.destination.id)",
                qualifier: .recommended,
                durationSeconds: walkToChateletSeconds + transitSeconds,
                walkingDurationSeconds: walkToChateletSeconds,
                transferCount: 0,
                departureAt: viaTimestamp(departure),
                arrivalAt: viaTimestamp(arrival),
                status: .normal,
                warnings: [],
                sections: [
                    JourneySection(
                        type: .walk,
                        durationSeconds: walkToChateletSeconds,
                        from: origin,
                        to: JourneyPlace(name: chatelet.name, coordinate: chatelet.coordinate),
                        departureAt: viaTimestamp(departure),
                        arrivalAt: viaTimestamp(walkArrival),
                        geometry: [origin.coordinate, chatelet.coordinate],
                        route: nil,
                        direction: nil,
                        platform: nil,
                        stops: []
                    ),
                    JourneySection(
                        type: .transit,
                        durationSeconds: transitSeconds,
                        from: JourneyPlace(name: chatelet.name, coordinate: chatelet.coordinate),
                        to: destination,
                        departureAt: viaTimestamp(walkArrival),
                        arrivalAt: viaTimestamp(arrival),
                        geometry: route.segments.first?.coordinates ?? [],
                        route: journeyRoute,
                        direction: "Château de Vincennes",
                        platform: nil,
                        stops: []
                    ),
                ]
            )
        }

        let alternative = walkingJourney(
            id: "demo:walk-alternative:\(request.destination.id)",
            qualifier: .walking,
            origin: origin,
            destination: destination,
            start: departure,
            seconds: max(primary.durationSeconds + 6 * 60, Int(request.origin.distance(to: request.destination.coordinate) / 1.25))
        )

        return JourneysResponse(
            status: .ready,
            source: .idfmRealtime,
            generatedAt: viaTimestamp(generatedAt),
            journeys: [primary, alternative]
        )
    }

    private func walkingJourney(
        id: String,
        qualifier: JourneyQualifier,
        origin: JourneyPlace,
        destination: JourneyPlace,
        start: Date,
        seconds: Int
    ) -> Journey {
        let arrival = start.addingTimeInterval(Double(seconds))
        return Journey(
            id: id,
            qualifier: qualifier,
            durationSeconds: seconds,
            walkingDurationSeconds: seconds,
            transferCount: 0,
            departureAt: viaTimestamp(start),
            arrivalAt: viaTimestamp(arrival),
            status: .normal,
            warnings: [],
            sections: [
                JourneySection(
                    type: .walk,
                    durationSeconds: seconds,
                    from: origin,
                    to: destination,
                    departureAt: viaTimestamp(start),
                    arrivalAt: viaTimestamp(arrival),
                    geometry: [origin.coordinate, destination.coordinate],
                    route: nil,
                    direction: nil,
                    platform: nil,
                    stops: []
                ),
            ]
        )
    }
}

private func viaTimestamp(_ date: Date) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.string(from: date)
}
