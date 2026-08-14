import Foundation
import ViaAPIContract

/// Maps the generated OpenAPI contract into the domain seam consumed by features.
///
/// No generated transport type crosses this boundary. That keeps API contract
/// churn local to one adapter and leaves reducers, models, and views domain-only.
final class OpenAPITransitAPI: TransitAPI, @unchecked Sendable {
    private let client: ViaAPIClient
    private let logger: ViaLogger

    init(
        baseURL: URL,
        clientIdentifier: String,
        clientMetadata: NativeClientMetadata = .current,
        session: URLSession = .shared,
        logger: ViaLogger = ViaLogger(category: "network")
    ) {
        client = ViaAPIClient(
            baseURL: baseURL,
            clientIdentifier: clientIdentifier,
            clientPlatform: clientMetadata.platform,
            clientVersion: clientMetadata.version,
            clientBuild: clientMetadata.build,
            session: session
        )
        self.logger = logger
    }

    func loadRailMap() async throws -> RailMap {
        try await request(
            operationName: "network.railMap",
            path: "/api/network/rail-map",
            execute: { try await client.loadRailMap() },
            decode: mapRailMap
        )
    }

    func loadStations(in bounds: TileBounds) async throws -> StationsInArea {
        try await request(
            operationName: "network.stationsInArea",
            path: "/api/network/stations-in-area",
            execute: {
                try await client.loadStations(
                    minLatitude: bounds.minLatitude,
                    maxLatitude: bounds.maxLatitude,
                    minLongitude: bounds.minLongitude,
                    maxLongitude: bounds.maxLongitude
                )
            },
            decode: mapStationsInArea
        )
    }

    func search(query: String, near coordinate: GeoCoordinate?) async throws -> SearchResponse {
        try await request(
            operationName: "search.query",
            path: "/api/search",
            execute: {
                try await client.search(
                    query: query,
                    limit: 10,
                    latitude: coordinate?.latitude.rounded(toPlaces: 4),
                    longitude: coordinate?.longitude.rounded(toPlaces: 4)
                )
            },
            decode: mapSearchResponse
        )
    }

    func loadDepartures(stationID: String) async throws -> DeparturesResponse {
        try await request(
            operationName: "departures.forStation",
            path: "/api/departures",
            execute: { try await client.loadDepartures(stationID: stationID) },
            decode: mapDeparturesResponse
        )
    }

    func planJourneys(_ request: JourneyRequest) async throws -> JourneysResponse {
        try await self.request(
            operationName: "journeys.plan",
            path: "/api/journeys",
            execute: {
                try await client.planJourneys(
                    originLatitude: request.origin.latitude,
                    originLongitude: request.origin.longitude,
                    destinationKind: request.destination.kind.rawValue,
                    destinationID: request.destination.id,
                    destinationName: request.destination.name,
                    destinationContext: request.destination.context,
                    destinationLatitude: request.destination.coordinate.latitude,
                    destinationLongitude: request.destination.coordinate.longitude,
                    limit: request.limit
                )
            },
            decode: mapJourneysResponse
        )
    }

    private func request<Response, Value>(
        operationName: String,
        path: String,
        execute work: () async throws -> Response,
        decode: (Response) throws -> Value
    ) async throws -> Value {
        let startedAt = Date()
        logger.requestStarted(operation: operationName, path: path)
        do {
            let value = try decode(await work())
            logger.requestSucceeded(
                operation: operationName,
                path: path,
                durationMilliseconds: max(0, Int(Date().timeIntervalSince(startedAt) * 1_000))
            )
            return value
        } catch {
            let mappedError = TransitAPIError.from(error)
            logger.requestFailed(operation: operationName, path: path, error: mappedError)
            throw mappedError
        }
    }

    private func mapRailMap(
        _ output: Operations.Network_railMap.Output
    ) throws -> RailMap {
        let body = try output.ok.body.json
        return RailMap(
            routes: try body.routes.map { route in
                NetworkRoute(
                    id: route.id,
                    shortName: route.shortName,
                    mode: try transitMode(route.mode.rawValue),
                    color: route.color,
                    textColor: route.textColor,
                    segments: route.segments.map { segment in
                        NetworkSegment(
                            id: segment.id,
                            coordinates: segment.coordinates.map {
                                coordinate(latitude: $0.latitude, longitude: $0.longitude)
                            }
                        )
                    }
                )
            },
            stations: body.stations.map { station in
                NetworkStation(
                    id: station.id,
                    name: station.name,
                    coordinate: coordinate(
                        latitude: station.coordinate.latitude,
                        longitude: station.coordinate.longitude
                    ),
                    routeIds: station.routeIds
                )
            }
        )
    }

    private func mapStationsInArea(
        _ output: Operations.Network_stationsInArea.Output
    ) throws -> StationsInArea {
        let body = try output.ok.body.json
        return StationsInArea(
            stations: body.stations.map { station in
                NetworkStation(
                    id: station.id,
                    name: station.name,
                    coordinate: coordinate(
                        latitude: station.coordinate.latitude,
                        longitude: station.coordinate.longitude
                    ),
                    routeIds: station.routeIds
                )
            },
            routes: try body.routes.map { route in
                RouteBadge(
                    id: route.id,
                    shortName: route.shortName,
                    mode: try transitMode(route.mode.rawValue),
                    color: route.color,
                    textColor: route.textColor
                )
            }
        )
    }

    private func mapSearchResponse(
        _ output: Operations.Search_query.Output
    ) throws -> SearchResponse {
        let body = try output.ok.body.json
        let results = try body.results.map { result -> SearchResult in
            if let station = result.value1 {
                return .station(
                    StationSearchResult(
                        id: station.id,
                        name: station.name,
                        coordinate: coordinate(
                            latitude: station.coordinate.latitude,
                            longitude: station.coordinate.longitude
                        ),
                        routes: try station.routes.map { route in
                            RouteBadge(
                                id: route.id,
                                shortName: route.shortName,
                                mode: try transitMode(route.mode.rawValue),
                                color: route.color,
                                textColor: route.textColor
                            )
                        },
                        distanceMeters: station.distanceMeters
                    )
                )
            }

            if let address = result.value2 {
                return .address(
                    AddressSearchResult(
                        id: address.id,
                        name: address.name,
                        context: address.context,
                        coordinate: coordinate(
                            latitude: address.coordinate.latitude,
                            longitude: address.coordinate.longitude
                        ),
                        distanceMeters: address.distanceMeters
                    )
                )
            }

            throw TransitAPIError.contractViolation
        }
        guard let ban = SearchResponse.BANStatus(rawValue: body.sources.ban.rawValue) else {
            throw TransitAPIError.contractViolation
        }
        return SearchResponse(results: results, sources: .init(ban: ban))
    }

    private func mapDeparturesResponse(
        _ output: Operations.Departures_forStation.Output
    ) throws -> DeparturesResponse {
        let body = try output.ok.body.json
        guard let source = DeparturesResponse.Source(rawValue: body.source.rawValue) else {
            throw TransitAPIError.contractViolation
        }
        return DeparturesResponse(
            source: source,
            generatedAt: timestamp(body.generatedAt),
            groups: try body.groups.map { group in
                DepartureGroup(
                    route: RouteBadge(
                        id: group.route.id,
                        shortName: group.route.shortName,
                        mode: try transitMode(group.route.mode.rawValue),
                        color: group.route.color,
                        textColor: group.route.textColor
                    ),
                    destination: group.destination,
                    departures: group.departures.map(timestamp)
                )
            }
        )
    }

    private func mapJourneysResponse(
        _ output: Operations.Journeys_plan.Output
    ) throws -> JourneysResponse {
        let body = try output.ok.body.json
        guard let status = JourneysResponse.Status(rawValue: body.status.rawValue) else {
            throw TransitAPIError.contractViolation
        }
        let source = body.source.flatMap { JourneysResponse.Source(rawValue: $0.rawValue) }
        return JourneysResponse(
            status: status,
            source: source,
            generatedAt: timestamp(body.generatedAt),
            journeys: try body.journeys.map { journey in
                guard let qualifier = JourneyQualifier(rawValue: journey.qualifier.rawValue),
                    let status = JourneyStatus(rawValue: journey.status.rawValue)
                else {
                    throw TransitAPIError.contractViolation
                }
                return Journey(
                    id: journey.id,
                    qualifier: qualifier,
                    durationSeconds: journey.durationSeconds,
                    walkingDurationSeconds: journey.walkingDurationSeconds,
                    transferCount: journey.transferCount,
                    departureAt: timestamp(journey.departureAt),
                    arrivalAt: timestamp(journey.arrivalAt),
                    status: status,
                    warnings: journey.warnings,
                    sections: try journey.sections.map { section in
                        guard let type = JourneySectionType(rawValue: section._type.rawValue) else {
                            throw TransitAPIError.contractViolation
                        }
                        return JourneySection(
                            type: type,
                            durationSeconds: section.durationSeconds,
                            from: JourneyPlace(
                                name: section.from.name,
                                coordinate: coordinate(
                                    latitude: section.from.coordinate.latitude,
                                    longitude: section.from.coordinate.longitude
                                )
                            ),
                            to: JourneyPlace(
                                name: section.to.name,
                                coordinate: coordinate(
                                    latitude: section.to.coordinate.latitude,
                                    longitude: section.to.coordinate.longitude
                                )
                            ),
                            departureAt: section.departureAt.map(timestamp),
                            arrivalAt: section.arrivalAt.map(timestamp),
                            geometry: section.geometry.map {
                                coordinate(latitude: $0.latitude, longitude: $0.longitude)
                            },
                            route: try section.route.map { route in
                                JourneyRoute(
                                    id: route.id,
                                    shortName: route.shortName,
                                    longName: route.longName,
                                    mode: try transitMode(route.mode.rawValue),
                                    color: route.color,
                                    textColor: route.textColor
                                )
                            },
                            direction: section.direction,
                            platform: section.platform,
                            stops: (section.stops ?? []).map { stop in
                                JourneyStop(
                                    id: stop.id,
                                    name: stop.name,
                                    coordinate: coordinate(
                                        latitude: stop.coordinate.latitude,
                                        longitude: stop.coordinate.longitude
                                    ),
                                    arrivalAt: stop.arrivalAt.map(timestamp),
                                    departureAt: stop.departureAt.map(timestamp)
                                )
                            }
                        )
                    }
                )
            }
        )
    }

    private func coordinate(latitude: Double, longitude: Double) -> GeoCoordinate {
        GeoCoordinate(latitude: latitude, longitude: longitude)
    }

    private func transitMode(_ rawValue: String) throws -> TransitMode {
        guard let mode = TransitMode(rawValue: rawValue) else {
            throw TransitAPIError.contractViolation
        }
        return mode
    }

    private func timestamp(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }

}

private extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let power = pow(10, Double(places))
        return (self * power).rounded() / power
    }
}
