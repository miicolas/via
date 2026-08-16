import Foundation

protocol SearchRepository: Sendable {
    func search(query: String, near coordinate: GeoCoordinate?) async throws -> SearchResponse
}

struct LiveSearchRepository: SearchRepository {
    let transport: ViaTransport

    func search(query: String, near coordinate: GeoCoordinate?) async throws -> SearchResponse {
        try await transport.perform("search") { client in
            let coordinate = coordinate?.roundedForSearch
            let input = Operations.search_period_query.Input(query: .init(
                q: query,
                latitude: coordinate?.latitude,
                longitude: coordinate?.longitude,
                limit: 10
            ))
            switch try await client.search_period_query(input) {
            case .ok(let response):
                return try transport.convert(response.body.json, to: SearchResponseDTO.self).domain()
            case .undocumented(let statusCode, _):
                throw ViaTransport.error(for: statusCode)
            }
        }
    }
}

struct InMemorySearchRepository: SearchRepository {
    var response: SearchResponse = .init(results: [], addressSource: .ok)
    func search(query: String, near coordinate: GeoCoordinate?) async throws -> SearchResponse { response }
}
