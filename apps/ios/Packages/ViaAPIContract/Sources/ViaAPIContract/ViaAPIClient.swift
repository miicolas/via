import Foundation
import HTTPTypes
import OpenAPIRuntime
import OpenAPIURLSession

/// The generated OpenAPI client with Via's shared transport configuration.
///
/// The application owns the domain adapter. This module owns the generated
/// contract, URLSession transport, and request identity middleware so those
/// implementation details do not leak into feature code.
public struct ViaAPIClient: Sendable {
    private let client: Client

    public init(
        baseURL: URL,
        clientIdentifier: String,
        session: URLSession = .shared
    ) {
        let transport = URLSessionTransport(
            configuration: .init(session: session)
        )
        client = Client(
            serverURL: Self.apiURL(for: baseURL),
            transport: transport,
            middlewares: [ClientIdentityMiddleware(value: clientIdentifier)]
        )
    }

    public func loadRailMap() async throws -> Operations.Network_railMap.Output {
        try await client.network_railMap()
    }

    public func loadStations(
        minLatitude: Double,
        maxLatitude: Double,
        minLongitude: Double,
        maxLongitude: Double
    ) async throws -> Operations.Network_stationsInArea.Output {
        try await client.network_stationsInArea(
            query: .init(
                minLatitude: minLatitude,
                maxLatitude: maxLatitude,
                minLongitude: minLongitude,
                maxLongitude: maxLongitude
            )
        )
    }

    public func search(
        query: String,
        limit: Int,
        latitude: Double?,
        longitude: Double?
    ) async throws -> Operations.Search_query.Output {
        try await client.search_query(
            query: .init(
                q: query,
                latitude: latitude,
                longitude: longitude,
                limit: limit
            )
        )
    }

    public func loadDepartures(
        stationID: String
    ) async throws -> Operations.Departures_forStation.Output {
        try await client.departures_forStation(
            query: .init(stationId: stationID)
        )
    }

    public func planJourneys(
        originLatitude: Double,
        originLongitude: Double,
        destination: Operations.Journeys_plan.Input.Query.DestinationPayload,
        limit: Int
    ) async throws -> Operations.Journeys_plan.Output {
        try await client.journeys_plan(
            query: .init(
                origin: .init(latitude: originLatitude, longitude: originLongitude),
                destination: destination,
                limit: limit
            )
        )
    }

    private static func apiURL(for baseURL: URL) -> URL {
        let normalizedPath = baseURL.path
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard normalizedPath.split(separator: "/").last != "api" else {
            return baseURL
        }
        return baseURL.appendingPathComponent("api")
    }
}

private struct ClientIdentityMiddleware: ClientMiddleware {
    let value: String

    func intercept(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String,
        next: @Sendable (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPResponse, HTTPBody?) {
        var request = request
        request.headerFields[HTTPField.Name("x-via-client-id")!] = value
        return try await next(request, body, baseURL)
    }
}
