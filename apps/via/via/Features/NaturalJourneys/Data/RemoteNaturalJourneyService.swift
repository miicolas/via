import Foundation

/// Server-side natural-language planning: the same repository contract as the
/// on-device pipeline, answered by Via's API when Apple Intelligence cannot
/// take the request. Only initial submissions travel — every follow-up to a
/// clarification or decision is deterministic and stays on the device.
struct RemoteNaturalJourneyService: NaturalJourneyRepository {
    let transport: APITransport
    var now: @Sendable () -> Date = { .now }

    func submit(_ request: NaturalJourneyRequest) async throws -> NaturalJourneyResult {
        guard case .submit(let query, let currentLocation) = request else {
            // A draft only exists because the on-device parser produced one;
            // the composing repository never routes those here.
            assertionFailure("RemoteNaturalJourneyService only handles initial submissions")
            throw ViaError.transport
        }

        return try await transport.perform("natural-journeys") { client in
            let body = Operations.naturalJourneys_period_submit.Input.Body.jsonPayload(
                // The contract bounds the phrase at 500 characters.
                query: String(query.prefix(500)),
                latitude: currentLocation?.latitude,
                longitude: currentLocation?.longitude,
                // The device clock, so the server resolves "dans 20 minutes"
                // against the traveller's "now" rather than its own.
                requestedAt: now(),
            )
            let input = Operations.naturalJourneys_period_submit.Input(body: .json(body))
            switch try await client.naturalJourneys_period_submit(input) {
            case .ok(let response):
                return try transport.convert(
                    response.body.json,
                    to: NaturalJourneyResponseDTO.self,
                ).domain()
            case .undocumented(let statusCode, _):
                throw APITransport.error(for: statusCode)
            }
        }
    }
}
