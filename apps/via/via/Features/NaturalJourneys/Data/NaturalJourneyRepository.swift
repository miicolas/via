import Foundation

protocol NaturalJourneyRepository: Sendable {
    func submit(_ request: NaturalJourneyRequest) async throws -> NaturalJourneyResult
}

struct LiveNaturalJourneyRepository: NaturalJourneyRepository {
    let transport: APITransport

    func submit(_ request: NaturalJourneyRequest) async throws -> NaturalJourneyResult {
        try await transport.perform("natural_journey") { client in
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
            let payload = try transport.convert(dto, to: Payload.self)
            let input = Operations.naturalJourneys_period_submit.Input(body: .json(payload))
            switch try await client.naturalJourneys_period_submit(input) {
            case .ok(let response):
                return try transport.convert(
                    response.body.json,
                    to: NaturalJourneyResultDTO.self
                ).domain()
            case .undocumented(let statusCode, _):
                throw APITransport.error(for: statusCode)
            }
        }
    }
}

struct InMemoryNaturalJourneyRepository: NaturalJourneyRepository {
    var result: NaturalJourneyResult = .unsupported(message: "Aucun itinéraire de prévisualisation", examples: [])
    func submit(_ request: NaturalJourneyRequest) async throws -> NaturalJourneyResult { result }
}
