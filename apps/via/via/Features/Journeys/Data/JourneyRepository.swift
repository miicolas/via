import Foundation

protocol JourneyRepository: Sendable {
    func plan(_ request: JourneyRequest) async throws -> JourneyResult
}

struct LiveJourneyRepository: JourneyRepository {
    let transport: ViaTransport

    func plan(_ request: JourneyRequest) async throws -> JourneyResult {
        try await transport.perform("journeys") { client in
            typealias Query = Operations.journeys_period_plan.Input.Query
            let destination = try transport.convert(
                JourneyDestinationDTO(request.destination),
                to: Query.destinationPayload.self
            )
            let input = Operations.journeys_period_plan.Input(query: Query(
                origin: .init(
                    latitude: request.origin.latitude,
                    longitude: request.origin.longitude
                ),
                destination: destination,
                limit: request.limit,
                requestedAt: request.requestedAt,
                datetimeRepresents: request.datetimeRepresents.flatMap {
                    Query.datetimeRepresentsPayload(rawValue: $0.rawValue)
                },
                requiredModes: request.requiredModes.compactMap {
                    Query.requiredModesPayloadPayload(rawValue: $0.rawValue)
                },
                excludedModes: request.excludedModes.compactMap {
                    Query.excludedModesPayloadPayload(rawValue: $0.rawValue)
                },
                preferredModes: request.preferredModes.compactMap {
                    Query.preferredModesPayloadPayload(rawValue: $0.rawValue)
                }
            ))
            switch try await client.journeys_period_plan(input) {
            case .ok(let response):
                return try transport.convert(response.body.json, to: JourneyResultDTO.self).domain()
            case .undocumented(let statusCode, _):
                throw ViaTransport.error(for: statusCode)
            }
        }
    }
}

struct InMemoryJourneyRepository: JourneyRepository {
    var result: JourneyResult = .init(status: .noRoute, source: nil, generatedAt: .now, journeys: [])
    func plan(_ request: JourneyRequest) async throws -> JourneyResult { result }
}
