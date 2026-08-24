import Foundation

protocol SearchRepository: Sendable {
    func search(
        query: String,
        near coordinate: GeoCoordinate?,
        bikeStationsOnly: Bool
    ) async throws -> SearchResponse
}

extension SearchRepository {
    func search(query: String, near coordinate: GeoCoordinate?) async throws -> SearchResponse {
        try await search(query: query, near: coordinate, bikeStationsOnly: false)
    }
}

struct LiveSearchRepository: SearchRepository {
    let transport: APITransport

    func search(
        query: String,
        near coordinate: GeoCoordinate?,
        bikeStationsOnly: Bool
    ) async throws -> SearchResponse {
        try await transport.perform("search") { client in
            let coordinate = coordinate?.roundedForSearch
            let input = Operations.search_period_query.Input(query: .init(
                q: query,
                latitude: coordinate?.latitude,
                longitude: coordinate?.longitude,
                limit: 10,
                bikeStationsOnly: bikeStationsOnly,
            ))
            switch try await client.search_period_query(input) {
            case .ok(let response):
                return try transport.convert(response.body.json, to: SearchResponseDTO.self).domain()
            case .undocumented(let statusCode, _):
                throw APITransport.error(for: statusCode)
            }
        }
    }
}

struct InMemorySearchRepository: SearchRepository {
    var response: SearchResponse = .init(results: [], addressSource: .ok)
    func search(
        query: String,
        near coordinate: GeoCoordinate?,
        bikeStationsOnly: Bool
    ) async throws -> SearchResponse { response }
}
