import Foundation
import OpenAPIRuntime

protocol JourneyRepository: Sendable {
    func plan(_ request: JourneyRequest) async throws -> JourneyResult
}

struct LiveJourneyRepository: JourneyRepository {
    let transport: APITransport

    func plan(_ request: JourneyRequest) async throws -> JourneyResult {
        try await transport.perform("journeys") { client in
            typealias Query = Operations.journeys_period_plan.Input.Query
            let input = Operations.journeys_period_plan.Input(query: Query(
                origin: .init(
                    latitude: request.origin.latitude,
                    longitude: request.origin.longitude
                ),
                destination: Self.destinationPayload(request.destination),
                limit: request.limit,
                requestedAt: request.requestedAt,
                datetimeRepresents: request.datetimeRepresents.flatMap {
                    Query.datetimeRepresentsPayload(rawValue: $0.rawValue)
                },
                requiredModes: Self.modeList(request.requiredModes),
                excludedModes: Self.modeList(request.excludedModes),
                preferredModes: Self.modeList(request.preferredModes)
            ))
            switch try await client.journeys_period_plan(input) {
            case .ok(let response):
                return try transport.convert(response.body.json, to: JourneyResultDTO.self).domain()
            case .undocumented(let statusCode, _):
                throw APITransport.error(for: statusCode)
            }
        }
    }

    /// The wire keeps destination one level deep: deepObject query
    /// serialization rejects nested containers, so `coordinate` rides as
    /// `latitude`/`longitude` and the server folds it back.
    private static func destinationPayload(
        _ destination: JourneyDestination
    ) -> Operations.journeys_period_plan.Input.Query.destinationPayload {
        switch destination {
        case .station(let id, let name, let coordinate):
            .init(value1: .init(
                kind: "station",
                id: id.rawValue,
                name: name,
                latitude: coordinate.latitude,
                longitude: coordinate.longitude
            ))
        case .address(let id, let name, let context, let coordinate):
            .init(value2: .init(
                kind: "address",
                id: id,
                name: name,
                context: context,
                latitude: coordinate.latitude,
                longitude: coordinate.longitude
            ))
        }
    }

    /// Modes ride as CSV for the same reason; sorted so equal requests
    /// produce byte-identical URLs and share an HTTP cache entry.
    private static func modeList(_ modes: Set<TransitMode>) -> String? {
        guard !modes.isEmpty else { return nil }
        return modes.map(\.rawValue).sorted().joined(separator: ",")
    }
}

struct InMemoryJourneyRepository: JourneyRepository {
    var result: JourneyResult = .init(status: .noRoute, source: nil, generatedAt: .now, journeys: [])
    func plan(_ request: JourneyRequest) async throws -> JourneyResult { result }
}
