import Foundation

protocol NaturalJourneyRepository: Sendable {
    func submit(_ request: NaturalJourneyRequest) async throws -> NaturalJourneyResult
}

struct LiveNaturalJourneyRepository: NaturalJourneyRepository {
    let client: any ViaAPIClient
    func submit(_ request: NaturalJourneyRequest) async throws -> NaturalJourneyResult { try await client.naturalJourney(request) }
}

struct InMemoryNaturalJourneyRepository: NaturalJourneyRepository {
    var result: NaturalJourneyResult = .unsupported(message: "Aucun itinéraire de prévisualisation", examples: [])
    func submit(_ request: NaturalJourneyRequest) async throws -> NaturalJourneyResult { result }
}
