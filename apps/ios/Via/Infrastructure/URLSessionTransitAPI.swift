import Foundation

final class URLSessionTransitAPI: TransitAPI, @unchecked Sendable {
    private let baseURL: URL
    private let clientIdentifier: String
    private let session: URLSession

    init(baseURL: URL, clientIdentifier: String, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.clientIdentifier = clientIdentifier
        self.session = session
    }

    func loadRailMap() async throws -> RailMap {
        try await request(path: "/api/network/rail-map", query: [])
    }

    func loadStations(in bounds: TileBounds) async throws -> StationsInArea {
        try await request(
            path: "/api/network/stations",
            query: [
                URLQueryItem(name: "minLatitude", value: String(bounds.minLatitude)),
                URLQueryItem(name: "maxLatitude", value: String(bounds.maxLatitude)),
                URLQueryItem(name: "minLongitude", value: String(bounds.minLongitude)),
                URLQueryItem(name: "maxLongitude", value: String(bounds.maxLongitude)),
            ]
        )
    }

    func search(query: String, near coordinate: GeoCoordinate?) async throws -> SearchResponse {
        var items = [URLQueryItem(name: "q", value: query), URLQueryItem(name: "limit", value: "10")]
        if let coordinate {
            items.append(URLQueryItem(name: "latitude", value: String(coordinate.latitude.rounded(toPlaces: 4))))
            items.append(URLQueryItem(name: "longitude", value: String(coordinate.longitude.rounded(toPlaces: 4))))
        }
        return try await request(path: "/api/search", query: items)
    }

    func loadDepartures(stationID: String) async throws -> DeparturesResponse {
        try await request(
            path: "/api/departures",
            query: [URLQueryItem(name: "stationId", value: stationID)]
        )
    }

    func planJourneys(_ request: JourneyRequest) async throws -> JourneysResponse {
        let destination = request.destination
        return try await self.request(
            path: "/api/journeys",
            query: [
                URLQueryItem(name: "origin[latitude]", value: String(request.origin.latitude)),
                URLQueryItem(name: "origin[longitude]", value: String(request.origin.longitude)),
                URLQueryItem(name: "destination[kind]", value: destination.kind.rawValue),
                URLQueryItem(name: "destination[id]", value: destination.id),
                URLQueryItem(name: "destination[name]", value: destination.name),
                URLQueryItem(name: "destination[coordinate][latitude]", value: String(destination.coordinate.latitude)),
                URLQueryItem(name: "destination[coordinate][longitude]", value: String(destination.coordinate.longitude)),
                URLQueryItem(name: "limit", value: String(request.limit)),
            ]
        )
    }

    private func request<Response: Decodable>(path: String, query: [URLQueryItem]) async throws -> Response {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw TransitAPIError.invalidURL
        }
        let basePath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        components.path = "/" + ([basePath, path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))]
            .filter { !$0.isEmpty }
            .joined(separator: "/"))
        components.queryItems = query
        guard let url = components.url else { throw TransitAPIError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.cachePolicy = .useProtocolCachePolicy
        request.setValue(clientIdentifier, forHTTPHeaderField: "x-via-client-id")

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw TransitAPIError.server(statusCode: 0)
            }
            guard (200..<300).contains(httpResponse.statusCode) else {
                throw error(for: httpResponse.statusCode)
            }

            do {
                return try JSONDecoder().decode(Response.self, from: data)
            } catch {
                throw TransitAPIError.decoding
            }
        } catch let error as TransitAPIError {
            throw error
        } catch let error as URLError {
            switch error.code {
            case .cancelled: throw TransitAPIError.cancelled
            case .timedOut: throw TransitAPIError.timeout
            case .notConnectedToInternet, .networkConnectionLost, .cannotFindHost, .cannotConnectToHost:
                throw TransitAPIError.offline
            default: throw TransitAPIError.server(statusCode: 0)
            }
        } catch is CancellationError {
            throw TransitAPIError.cancelled
        } catch {
            throw TransitAPIError.server(statusCode: 0)
        }
    }

    private func error(for statusCode: Int) -> TransitAPIError {
        switch statusCode {
        case 401, 403: .unauthorized
        case 429: .rateLimited
        default: .server(statusCode: statusCode)
        }
    }
}

private extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let power = pow(10, Double(places))
        return (self * power).rounded() / power
    }
}
