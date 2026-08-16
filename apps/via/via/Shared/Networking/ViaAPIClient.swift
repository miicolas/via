import Foundation
import HTTPTypes
import OpenAPIRuntime
import OpenAPIURLSession

protocol ViaAPIClient: Sendable {
    func syncAccount(operations: [AccountSyncOperation]) async throws -> AccountSyncResult
    func deleteAccount(identityToken: String, authorizationCode: String, nonce: String) async throws
    func loadRailMap() async throws -> TransitNetwork
    func loadStations(in bounds: GeoBounds) async throws -> StationsArea
    func search(query: String, near coordinate: GeoCoordinate?, limit: Int) async throws -> SearchResponse
    func departures(stationID: StationID) async throws -> DepartureBoard
    func journeys(_ request: JourneyRequest) async throws -> JourneyResult
    func naturalJourney(_ request: NaturalJourneyRequest) async throws -> NaturalJourneyResult
}

final class LiveViaAPIClient: ViaAPIClient, @unchecked Sendable {
    private let client: Client

    init(baseURL: URL, authSessionVault: any AuthSessionVault) {
        let configuration = URLSessionConfiguration.default
        configuration.urlCache = URLCache(
            memoryCapacity: 32 * 1_024 * 1_024,
            diskCapacity: 256 * 1_024 * 1_024
        )
        configuration.requestCachePolicy = .useProtocolCachePolicy
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 60
        configuration.waitsForConnectivity = true
        configuration.httpAdditionalHeaders = ["Accept": "application/json"]
        let session = URLSession(configuration: configuration)
        let transport = URLSessionTransport(configuration: .init(session: session))
        client = Client(
            serverURL: baseURL,
            configuration: Configuration(dateTranscoder: .iso8601WithFractionalSeconds),
            transport: transport,
            middlewares: [
                BearerAuthenticationMiddleware(vault: authSessionVault),
                IdempotentGETRetryMiddleware(),
            ]
        )
    }

    func syncAccount(operations: [AccountSyncOperation]) async throws -> AccountSyncResult {
        try await perform("account_sync") {
            typealias Payload = Operations.account_period_sync.Input.Body.jsonPayload
            let payload = try decode(AccountSyncRequest(operations: operations), as: Payload.self)
            switch try await client.account_period_sync(.init(body: .json(payload))) {
            case .ok(let response):
                return try decode(response.body.json, as: AccountSyncResult.self)
            case .undocumented(let statusCode, _):
                throw Self.error(for: statusCode)
            }
        }
    }

    func deleteAccount(identityToken: String, authorizationCode: String, nonce: String) async throws {
        try await perform("account_delete") {
            let payload = Operations.account_period_delete.Input.Body.jsonPayload(
                identityToken: identityToken,
                authorizationCode: authorizationCode,
                nonce: nonce
            )
            switch try await client.account_period_delete(.init(body: .json(payload))) {
            case .ok:
                return
            case .undocumented(let statusCode, _):
                throw Self.error(for: statusCode)
            }
        }
    }

    func loadRailMap() async throws -> TransitNetwork {
        try await perform("rail_map") {
            switch try await client.network_period_railMap(.init()) {
            case .ok(let response):
                return try decode(response.body.json, as: RailMapDTO.self).domain()
            case .undocumented(let statusCode, _):
                throw Self.error(for: statusCode)
            }
        }
    }

    func loadStations(in bounds: GeoBounds) async throws -> StationsArea {
        guard bounds.isValid else { throw ViaError.invalidRequest("viewport") }
        return try await perform("stations_in_area") {
            let input = Operations.network_period_stationsInArea.Input(query: .init(
                minLatitude: bounds.minLatitude,
                maxLatitude: bounds.maxLatitude,
                minLongitude: bounds.minLongitude,
                maxLongitude: bounds.maxLongitude
            ))
            switch try await client.network_period_stationsInArea(input) {
            case .ok(let response):
                return try decode(response.body.json, as: StationsAreaDTO.self).domain()
            case .undocumented(let statusCode, _):
                throw Self.error(for: statusCode)
            }
        }
    }

    func search(query: String, near coordinate: GeoCoordinate?, limit: Int) async throws -> SearchResponse {
        try await perform("search") {
            let input = Operations.search_period_query.Input(query: .init(
                q: query,
                latitude: coordinate?.latitude,
                longitude: coordinate?.longitude,
                limit: limit
            ))
            switch try await client.search_period_query(input) {
            case .ok(let response):
                return try decode(response.body.json, as: SearchResponseDTO.self).domain()
            case .undocumented(let statusCode, _):
                throw Self.error(for: statusCode)
            }
        }
    }

    func departures(stationID: StationID) async throws -> DepartureBoard {
        try await perform("departures") {
            let input = Operations.departures_period_forStation.Input(query: .init(stationId: stationID.rawValue))
            switch try await client.departures_period_forStation(input) {
            case .ok(let response):
                return try decode(response.body.json, as: DepartureBoardDTO.self).domain()
            case .undocumented(let statusCode, _):
                throw Self.error(for: statusCode)
            }
        }
    }

    func journeys(_ request: JourneyRequest) async throws -> JourneyResult {
        try await perform("journeys") {
            typealias Query = Operations.journeys_period_plan.Input.Query
            let destination = try decode(
                JourneyDestinationDTO(request.destination),
                as: Query.destinationPayload.self
            )
            let input = Operations.journeys_period_plan.Input(query: Query(
                origin: .init(latitude: request.origin.latitude, longitude: request.origin.longitude),
                destination: destination,
                limit: request.limit,
                requestedAt: request.requestedAt,
                datetimeRepresents: request.datetimeRepresents.flatMap { Query.datetimeRepresentsPayload(rawValue: $0.rawValue) },
                requiredModes: request.requiredModes.compactMap { Query.requiredModesPayloadPayload(rawValue: $0.rawValue) },
                excludedModes: request.excludedModes.compactMap { Query.excludedModesPayloadPayload(rawValue: $0.rawValue) },
                preferredModes: request.preferredModes.compactMap { Query.preferredModesPayloadPayload(rawValue: $0.rawValue) }
            ))
            switch try await client.journeys_period_plan(input) {
            case .ok(let response):
                return try decode(response.body.json, as: JourneyResultDTO.self).domain()
            case .undocumented(let statusCode, _):
                throw Self.error(for: statusCode)
            }
        }
    }

    func naturalJourney(_ request: NaturalJourneyRequest) async throws -> NaturalJourneyResult {
        try await perform("natural_journey") {
            typealias Payload = Operations.naturalJourneys_period_submit.Input.Body.jsonPayload
            let dto: NaturalJourneyRequestDTO = switch request {
            case .submit(let query, let location):
                .submit(query: query, location: location.map(CoordinateDTO.init))
            case .resolve(let draft, let location, let origin, let destination, let time):
                .resolve(
                    draft: .init(draft),
                    location: location.map(CoordinateDTO.init),
                    origin: origin.map(SearchResultDTO.init),
                    destination: destination.map(SearchResultDTO.init),
                    time: time?.rawValue
                )
            }
            let payload = try decode(dto, as: Payload.self)
            let input = Operations.naturalJourneys_period_submit.Input(body: .json(payload))
            switch try await client.naturalJourneys_period_submit(input) {
            case .ok(let response):
                return try decode(response.body.json, as: NaturalJourneyResultDTO.self).domain()
            case .undocumented(let statusCode, _):
                throw Self.error(for: statusCode)
            }
        }
    }

    private func perform<Value>(
        _ operation: StaticString,
        _ work: () async throws -> Value
    ) async throws -> Value {
        let signpost = ViaLog.requestStarted(operation)
        defer { ViaLog.requestFinished(operation, identifier: signpost) }
        do {
            return try await work()
        } catch {
            if Self.isCancellation(error) { throw CancellationError() }
            throw Self.map(error)
        }
    }

    /// Bridges between domain models and generated payload types in either
    /// direction via a JSON round-trip; both sides share the same wire shape.
    private func decode<Payload: Encodable, DTO: Decodable>(_ payload: Payload, as type: DTO.Type) throws -> DTO {
        try JSONDecoder.via.decode(type, from: JSONEncoder.via.encode(payload))
    }

    private static func map(_ error: Error) -> ViaError {
        if let viaError = error as? ViaError { return viaError }
        if let clientError = error as? ClientError {
            if let statusCode = clientError.response?.status.code { return Self.error(for: statusCode) }
            return map(clientError.underlyingError)
        }
        if error is DecodingError || error is EncodingError { return .decoding }
        return .transport
    }

    private static func isCancellation(_ error: Error) -> Bool {
        if error is CancellationError { return true }
        if let urlError = error as? URLError { return urlError.code == .cancelled }
        if let clientError = error as? ClientError { return isCancellation(clientError.underlyingError) }
        return false
    }

    private static func error(for statusCode: Int) -> ViaError {
        switch statusCode {
        case 401: .unauthorized
        case 429: .rateLimited
        case 503: .unavailable
        default: .server(statusCode: statusCode)
        }
    }
}

private struct AccountSyncRequest: Encodable {
    let operations: [AccountSyncOperation]
}

extension Notification.Name {
    static let viaAuthenticatedRequestWasRejected = Notification.Name(
        "dev.via.app.authenticated-request-was-rejected"
    )
}

private struct BearerAuthenticationMiddleware: ClientMiddleware {
    let vault: any AuthSessionVault

    @concurrent
    nonisolated func intercept(
        _ request: HTTPTypes.HTTPRequest,
        body: OpenAPIRuntime.HTTPBody?,
        baseURL: URL,
        operationID: String,
        next: @concurrent @Sendable (HTTPTypes.HTTPRequest, OpenAPIRuntime.HTTPBody?, URL) async throws -> (HTTPTypes.HTTPResponse, OpenAPIRuntime.HTTPBody?)
    ) async throws -> (HTTPTypes.HTTPResponse, OpenAPIRuntime.HTTPBody?) {
        var request = request
        if let session = try? await vault.load() {
            request.headerFields[.authorization] = "Bearer \(session.bearerToken)"
        }

        let response = try await next(request, body, baseURL)
        if let name = HTTPField.Name("set-auth-token"),
           let bearer = response.0.headerFields[name],
           !bearer.isEmpty {
            try? await vault.updateBearer(bearer)
        }
        if response.0.status == .unauthorized {
            await MainActor.run {
                NotificationCenter.default.post(name: .viaAuthenticatedRequestWasRejected, object: nil)
            }
        }
        return response
    }
}

private struct IdempotentGETRetryMiddleware: ClientMiddleware {
    @concurrent
    nonisolated func intercept(
        _ request: HTTPTypes.HTTPRequest,
        body: OpenAPIRuntime.HTTPBody?,
        baseURL: URL,
        operationID: String,
        next: @concurrent @Sendable (HTTPTypes.HTTPRequest, OpenAPIRuntime.HTTPBody?, URL) async throws -> (HTTPTypes.HTTPResponse, OpenAPIRuntime.HTTPBody?)
    ) async throws -> (HTTPTypes.HTTPResponse, OpenAPIRuntime.HTTPBody?) {
        guard request.method == .get else { return try await next(request, body, baseURL) }
        do {
            let response = try await next(request, body, baseURL)
            guard (500...599).contains(response.0.status.code) else { return response }
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch let error as URLError where error.code.isRetryable {
            try await Task.sleep(for: .milliseconds(250))
            return try await next(request, body, baseURL)
        }
        try await Task.sleep(for: .milliseconds(250))
        return try await next(request, body, baseURL)
    }
}

private extension URLError.Code {
    var isRetryable: Bool {
        switch self {
        case .timedOut, .cannotFindHost, .cannotConnectToHost, .networkConnectionLost,
             .dnsLookupFailed, .notConnectedToInternet:
            true
        default:
            false
        }
    }
}

extension JSONDecoder {
    static let via: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let value = try decoder.singleValueContainer().decode(String.self)
            guard let date = ISO8601.parse(value) else {
                throw DecodingError.dataCorruptedError(
                    in: try decoder.singleValueContainer(),
                    debugDescription: "Invalid ISO-8601 date"
                )
            }
            return date
        }
        return decoder
    }()
}

extension JSONEncoder {
    static let via: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(ISO8601.string(date))
        }
        return encoder
    }()
}
