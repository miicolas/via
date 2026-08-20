protocol NaturalJourneyRepository: Sendable {
    func submit(_ request: NaturalJourneyRequest) async throws -> NaturalJourneyResult
}

struct InMemoryNaturalJourneyRepository: NaturalJourneyRepository {
    var result: NaturalJourneyResult = .unsupported(message: "Aucun itinéraire de prévisualisation", examples: [])
    func submit(_: NaturalJourneyRequest) async throws -> NaturalJourneyResult { result }
}
