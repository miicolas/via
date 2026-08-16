import Foundation

protocol SearchRepository: Sendable {
    func search(query: String, near coordinate: GeoCoordinate?) async throws -> SearchResponse
}

struct LiveSearchRepository: SearchRepository {
    let client: any ViaAPIClient
    func search(query: String, near coordinate: GeoCoordinate?) async throws -> SearchResponse {
        try await client.search(query: query, near: coordinate?.roundedForSearch, limit: 10)
    }
}

struct InMemorySearchRepository: SearchRepository {
    var response: SearchResponse = .init(results: [], addressSource: .ok)
    func search(query: String, near coordinate: GeoCoordinate?) async throws -> SearchResponse { response }
}
