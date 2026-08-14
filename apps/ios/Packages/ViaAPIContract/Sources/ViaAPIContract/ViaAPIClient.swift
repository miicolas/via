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
        clientPlatform: String = "ios-native",
        clientVersion: String = "0",
        clientBuild: String = "0",
        session: URLSession = .shared
    ) {
        let transport = URLSessionTransport(
            configuration: .init(session: session)
        )
        client = Client(
            serverURL: Self.apiURL(for: baseURL),
            transport: transport,
            middlewares: [
                ClientIdentityMiddleware(
                    value: clientIdentifier,
                    platform: clientPlatform,
                    version: clientVersion,
                    build: clientBuild
                )
            ]
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
        destinationKind: String,
        destinationID: String,
        destinationName: String,
        destinationContext: String?,
        destinationLatitude: Double,
        destinationLongitude: Double,
        limit: Int
    ) async throws -> Operations.Journeys_plan.Output {
        let coordinate = Operations.Journeys_plan.Input.Query.DestinationPayload.Value1Payload.CoordinatePayload(
            latitude: destinationLatitude,
            longitude: destinationLongitude
        )
        let destination: Operations.Journeys_plan.Input.Query.DestinationPayload
        if destinationKind == "station" {
            destination = .init(
                value1: .init(
                    kind: try! .init(unvalidatedValue: destinationKind),
                    id: destinationID,
                    name: destinationName,
                    coordinate: coordinate
                )
            )
        } else {
            let addressCoordinate = Operations.Journeys_plan.Input.Query.DestinationPayload.Value2Payload.CoordinatePayload(
                latitude: destinationLatitude,
                longitude: destinationLongitude
            )
            destination = .init(
                value2: .init(
                    kind: try! .init(unvalidatedValue: destinationKind),
                    id: destinationID,
                    name: destinationName,
                    context: destinationContext,
                    coordinate: addressCoordinate
                )
            )
        }
        return try await client.journeys_plan(
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
    let platform: String
    let version: String
    let build: String

    func intercept(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String,
        next: @Sendable (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPResponse, HTTPBody?) {
        var request = request
        request.headerFields[HTTPField.Name("x-via-client-id")!] = value
        request.headerFields[HTTPField.Name("x-via-client-platform")!] = platform
        request.headerFields[HTTPField.Name("x-via-client-version")!] = version
        request.headerFields[HTTPField.Name("x-via-client-build")!] = build
        return try await next(request, body, baseURL)
    }
}
