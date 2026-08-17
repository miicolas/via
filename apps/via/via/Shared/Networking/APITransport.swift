import Foundation
import HTTPTypes
import OpenAPIRuntime
import OpenAPIURLSession

struct APITransport: Sendable {
    let client: Client

    init(
        baseURL: URL,
        authSessionVault: any AuthSessionVault,
        onUnauthorized: @escaping @Sendable () async -> Void = {}
    ) {
        let configuration = URLSessionConfiguration.apiSessionConfiguration(base: .default)
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
                BearerAuthenticationMiddleware(
                    vault: authSessionVault,
                    onUnauthorized: onUnauthorized
                ),
                IdempotentGETRetryMiddleware(),
            ]
        )
    }

    init(client: Client) {
        self.client = client
    }

    func perform<Value>(
        _ operation: StaticString,
        _ work: (Client) async throws -> Value
    ) async throws -> Value {
        let signpost = AppLog.requestStarted(operation)
        defer { AppLog.requestFinished(operation, identifier: signpost) }
        do {
            return try await work(client)
        } catch {
            if Self.isCancellation(error) { throw CancellationError() }
            throw Self.map(error)
        }
    }

    /// Bridges domain DTOs and generated payload types that share a wire shape.
    func convert<Payload: Encodable, DTO: Decodable>(
        _ payload: Payload,
        to type: DTO.Type
    ) throws -> DTO {
        try JSONDecoder.via.decode(type, from: JSONEncoder.via.encode(payload))
    }

    static func error(for statusCode: Int) -> ViaError {
        switch statusCode {
        case 401: .unauthorized
        case 429: .rateLimited
        case 503: .unavailable
        default: .server(statusCode: statusCode)
        }
    }

    private static func map(_ error: Error) -> ViaError {
        if let viaError = error as? ViaError { return viaError }
        if let clientError = error as? ClientError {
            if let statusCode = clientError.response?.status.code {
                return Self.error(for: statusCode)
            }
            return map(clientError.underlyingError)
        }
        if error is DecodingError || error is EncodingError { return .decoding }
        return .transport
    }

    private static func isCancellation(_ error: Error) -> Bool {
        if error is CancellationError { return true }
        if let urlError = error as? URLError { return urlError.code == .cancelled }
        if let clientError = error as? ClientError {
            return isCancellation(clientError.underlyingError)
        }
        return false
    }
}

struct BearerAuthenticationMiddleware: ClientMiddleware {
    let vault: any AuthSessionVault
    let onUnauthorized: @Sendable () async -> Void

    @concurrent
    nonisolated func intercept(
        _ request: HTTPTypes.HTTPRequest,
        body: OpenAPIRuntime.HTTPBody?,
        baseURL: URL,
        operationID: String,
        next: @concurrent @Sendable (
            HTTPTypes.HTTPRequest,
            OpenAPIRuntime.HTTPBody?,
            URL
        ) async throws -> (HTTPTypes.HTTPResponse, OpenAPIRuntime.HTTPBody?)
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
            await onUnauthorized()
        }
        return response
    }
}

struct IdempotentGETRetryMiddleware: ClientMiddleware {
    @concurrent
    nonisolated func intercept(
        _ request: HTTPTypes.HTTPRequest,
        body: OpenAPIRuntime.HTTPBody?,
        baseURL: URL,
        operationID: String,
        next: @concurrent @Sendable (
            HTTPTypes.HTTPRequest,
            OpenAPIRuntime.HTTPBody?,
            URL
        ) async throws -> (HTTPTypes.HTTPResponse, OpenAPIRuntime.HTTPBody?)
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
