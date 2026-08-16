import Foundation

protocol JourneyRepository: Sendable {
    func plan(_ request: JourneyRequest) async throws -> JourneyResult
}

struct LiveJourneyRepository: JourneyRepository {
    let client: any ViaAPIClient
    func plan(_ request: JourneyRequest) async throws -> JourneyResult { try await client.journeys(request) }
}

struct InMemoryJourneyRepository: JourneyRepository {
    var result: JourneyResult = .init(status: .noRoute, source: nil, generatedAt: .now, journeys: [])
    func plan(_ request: JourneyRequest) async throws -> JourneyResult { result }
}
