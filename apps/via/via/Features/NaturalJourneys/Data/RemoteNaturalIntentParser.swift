import Foundation

/// Interpretation-only OpenAI adapter. It sends no coordinates and receives no
/// resolved place or journey; all authority stays in the shared iOS pipeline.
struct RemoteNaturalIntentParser: NaturalIntentParsing {
    let transport: APITransport

    var availability: NaturalLanguageAvailability { .available }

    func proposeIntent(
        _ request: NaturalIntentModelRequest
    ) async throws(NaturalIntentParsingError) -> NaturalIntentProposal {
        do {
            return try await transport.perform("natural-journey-interpretation") { client in
                typealias Body = Operations.naturalJourneys_period_submit.Input.Body.jsonPayload
                let anchors = Body.anchorsPayload(
                    origin: request.originAnchor.map { anchor in
                        Body.anchorsPayload.originPayload(
                            kind: {
                                switch anchor.place {
                                case .currentLocation: return .current_location
                                case .query: return .query
                                case .saved: return .saved
                                case .reference: return .context_reference
                                }
                            }(),
                            value: Self.wireValue(anchor.place),
                            evidence: anchor.evidence,
                        )
                    },
                    destination: request.destinationAnchor.map { anchor in
                        Body.anchorsPayload.destinationPayload(
                            kind: {
                                switch anchor.place {
                                case .currentLocation: return .current_location
                                case .query: return .query
                                case .saved: return .saved
                                case .reference: return .context_reference
                                }
                            }(),
                            value: Self.wireValue(anchor.place),
                            evidence: anchor.evidence,
                        )
                    },
                )
                let anchoredSavedPlaceIDs = Set([
                    request.originAnchor?.place.savedPlaceID,
                    request.destinationAnchor?.place.savedPlaceID,
                ].compactMap { $0 })
                let savedPlaces = request.savedPlaces
                    .filter { anchoredSavedPlaceIDs.contains($0.id) }
                    .map { place in
                    Body.savedPlacesPayloadPayload(
                        id: place.id,
                        // The server needs membership, not the user's label or
                        // address. Evidence in the locked anchor carries the
                        // exact words typed for this one turn.
                        label: place.kind.rawValue,
                        kind: {
                            switch place.kind {
                            case .home: return .home
                            case .work: return .work
                            case .custom: return .custom
                            }
                        }(),
                    )
                    }
                let locale: Body.localePayload = request.locale.language.languageCode?.identifier == "en"
                    ? .en
                    : .fr_hyphen_FR
                let body = Body(
                    query: String(request.phrase.prefix(500)),
                    locale: locale,
                    requestedAt: request.now,
                    hasCurrentLocation: request.hasCurrentLocation,
                    anchors: anchors,
                    savedPlaces: savedPlaces,
                )
                let input = Operations.naturalJourneys_period_submit.Input(body: .json(body))
                switch try await client.naturalJourneys_period_submit(input) {
                case .ok(let response):
                    let dto = try transport.convert(
                        response.body.json,
                        to: NaturalIntentResponseDTO.self,
                    )
                    return try dto.proposal(for: request)
                case .undocumented(let statusCode, _):
                    throw APITransport.error(for: statusCode)
                }
            }
        } catch is CancellationError {
            throw .cancelled
        } catch let error as NaturalIntentParsingError {
            throw error
        } catch {
            throw .modelFailed
        }
    }

    private static func wireValue(_ place: RoutePlaceIntent) -> String {
        switch place {
        case .currentLocation: ""
        case .query(let query): query
        case .saved(let place): place.id
        case .reference(let reference): reference.rawValue
        }
    }
}

private extension RoutePlaceIntent {
    var savedPlaceID: String? {
        guard case .saved(let place) = self else { return nil }
        return place.id
    }
}
