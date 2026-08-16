import Foundation

extension CoordinateDTO {
    init(_ value: GeoCoordinate) { self.init(latitude: value.latitude, longitude: value.longitude) }
    var domain: GeoCoordinate { GeoCoordinate(latitude: latitude, longitude: longitude) }
}

func makeRouteBadge(id: String, shortName: String, mode: String, color: String, textColor: String) throws -> RouteBadge {
    guard let mode = TransitMode(rawValue: mode) else { throw ViaError.decoding }
    return RouteBadge(id: RouteID(rawValue: id), shortName: shortName, mode: mode, colorHex: color, textColorHex: textColor)
}

extension RouteBadgeDTO {
    init(_ value: RouteBadge) {
        self.init(id: value.id.rawValue, shortName: value.shortName, mode: value.mode.rawValue, color: value.colorHex, textColor: value.textColorHex)
    }

    func domain() throws -> RouteBadge {
        try makeRouteBadge(id: id, shortName: shortName, mode: mode, color: color, textColor: textColor)
    }
}

extension NetworkStationDTO {
    func domain() -> NetworkStation {
        NetworkStation(id: StationID(rawValue: id), name: name, coordinate: coordinate.domain, routeIDs: routeIds.map(RouteID.init(rawValue:)))
    }
}

extension RailMapDTO {
    func domain() throws -> TransitNetwork {
        TransitNetwork(
            routes: try routes.map { route in
                let badge = try makeRouteBadge(id: route.id, shortName: route.shortName, mode: route.mode, color: route.color, textColor: route.textColor)
                return NetworkRoute(badge: badge, segments: route.segments.map { NetworkSegment(id: $0.id, coordinates: $0.coordinates.map(\.domain)) })
            },
            stations: stations.map { $0.domain() }
        )
    }
}

extension StationsAreaDTO {
    func domain() throws -> StationsArea {
        StationsArea(stations: stations.map { $0.domain() }, routes: try routes.map { try $0.domain() })
    }
}

extension SearchResultDTO {
    init(_ value: SearchResult) {
        switch value {
        case .station(let station):
            self = .station(.init(
                id: station.id.rawValue,
                name: station.name,
                coordinate: .init(station.coordinate),
                routes: station.routes.map(RouteBadgeDTO.init),
                distanceMeters: station.distanceMeters
            ))
        case .address(let address):
            self = .address(.init(
                id: address.id,
                name: address.name,
                context: address.context,
                coordinate: .init(address.coordinate),
                distanceMeters: address.distanceMeters
            ))
        }
    }

    func domain() throws -> SearchResult {
        switch self {
        case .station(let value):
            .station(StationSearchResult(
                id: StationID(rawValue: value.id),
                name: value.name,
                coordinate: value.coordinate.domain,
                routes: try value.routes.map { try $0.domain() },
                distanceMeters: value.distanceMeters
            ))
        case .address(let value):
            .address(AddressSearchResult(
                id: value.id,
                name: value.name,
                context: value.context,
                coordinate: value.coordinate.domain,
                distanceMeters: value.distanceMeters
            ))
        }
    }
}

extension SearchResponseDTO {
    func domain() throws -> SearchResponse {
        SearchResponse(results: try results.map { try $0.domain() }, addressSource: sources.ban == "ok" ? .ok : .unavailable)
    }
}

extension DepartureBoardDTO {
    func domain() throws -> DepartureBoard {
        guard let source = DepartureBoard.Source(rawValue: source) else { throw ViaError.decoding }
        return DepartureBoard(
            source: source,
            generatedAt: generatedAt,
            groups: try groups.map { DepartureGroup(route: try $0.route.domain(), destination: $0.destination, departures: $0.departures) }
        )
    }
}

extension JourneyDestinationDTO {
    init(_ value: JourneyDestination) {
        switch value {
        case .station(let id, let name, let coordinate):
            self = .station(.init(id: id.rawValue, name: name, coordinate: .init(coordinate)))
        case .address(let id, let name, let context, let coordinate):
            self = .address(.init(id: id, name: name, context: context, coordinate: .init(coordinate)))
        }
    }

    var domain: JourneyDestination {
        switch self {
        case .station(let value): .station(id: .init(rawValue: value.id), name: value.name, coordinate: value.coordinate.domain)
        case .address(let value): .address(id: value.id, name: value.name, context: value.context, coordinate: value.coordinate.domain)
        }
    }
}

extension JourneyResultDTO {
    func domain() throws -> JourneyResult {
        guard let status = JourneyResult.Status(rawValue: status) else { throw ViaError.decoding }
        let mappedSource = try source.map { value in
            guard let result = JourneyResult.Source(rawValue: value) else { throw ViaError.decoding }
            return result
        }
        return JourneyResult(
            status: status,
            source: mappedSource,
            generatedAt: generatedAt,
            journeys: try journeys.map { try $0.domain() }
        )
    }
}

private extension JourneyResultDTO.JourneyDTO {
    func domain() throws -> Journey {
        guard
            let qualifier = Journey.Qualifier(rawValue: qualifier),
            let status = Journey.Status(rawValue: status)
        else { throw ViaError.decoding }
        return Journey(
            id: JourneyID(rawValue: id),
            qualifier: qualifier,
            durationSeconds: durationSeconds,
            walkingDurationSeconds: walkingDurationSeconds,
            transferCount: transferCount,
            departureAt: departureAt,
            arrivalAt: arrivalAt,
            status: status,
            warnings: warnings,
            sections: try sections.enumerated().map { index, section in try section.domain(id: "\(id):\(index)") }
        )
    }
}

private extension JourneyResultDTO.SectionDTO {
    func domain(id: String) throws -> JourneySection {
        guard let kind = JourneySection.Kind(rawValue: type) else { throw ViaError.decoding }
        let mappedRoute = try route.map { value in
            guard let mode = TransitMode(rawValue: value.mode) else { throw ViaError.decoding }
            return JourneyRoute(
                id: RouteID(rawValue: value.id), shortName: value.shortName, longName: value.longName,
                mode: mode, colorHex: value.color, textColorHex: value.textColor
            )
        }
        return JourneySection(
            id: id,
            kind: kind,
            durationSeconds: durationSeconds,
            from: JourneyPlace(name: from.name, coordinate: from.coordinate.domain),
            to: JourneyPlace(name: to.name, coordinate: to.coordinate.domain),
            departureAt: departureAt,
            arrivalAt: arrivalAt,
            geometry: geometry.map(\.domain),
            route: mappedRoute,
            direction: direction,
            platform: platform,
            stops: stops.map {
                JourneyStop(id: $0.id, name: $0.name, coordinate: $0.coordinate.domain, arrivalAt: $0.arrivalAt, departureAt: $0.departureAt)
            }
        )
    }
}

extension RouteIntentDTO {
    init(_ value: RouteIntent) {
        let origin: OriginDTO = switch value.origin {
        case .currentLocation: .currentLocation
        case .place(let query): .place(query)
        }
        self.init(
            scope: value.scope.rawValue,
            origin: origin,
            destinationQuery: value.destinationQuery,
            requestedAt: value.requestedAt,
            datetimeRepresents: value.datetimeRepresents.rawValue,
            requiredModes: value.requiredModes.map(\.rawValue).sorted(),
            excludedModes: value.excludedModes.map(\.rawValue).sorted(),
            preferredModes: value.preferredModes.map(\.rawValue).sorted()
        )
    }

    func domain() throws -> RouteIntent {
        guard let scope = RouteIntent.Scope(rawValue: scope), let time = RouteIntent.TimeMeaning(rawValue: datetimeRepresents) else { throw ViaError.decoding }
        let mappedOrigin: RouteOriginIntent = switch origin {
        case .currentLocation: .currentLocation
        case .place(let query): .place(query: query)
        }
        return RouteIntent(
            scope: scope, origin: mappedOrigin, destinationQuery: destinationQuery, requestedAt: requestedAt,
            datetimeRepresents: time,
            requiredModes: Set(requiredModes.compactMap(TransitMode.init(rawValue:))),
            excludedModes: Set(excludedModes.compactMap(TransitMode.init(rawValue:))),
            preferredModes: Set(preferredModes.compactMap(TransitMode.init(rawValue:)))
        )
    }
}

extension NaturalJourneyDraftDTO {
    init(_ value: NaturalJourneyDraft) {
        self.init(intent: .init(value.intent), origin: value.origin.map(SearchResultDTO.init), destination: value.destination.map(SearchResultDTO.init))
    }
    func domain() throws -> NaturalJourneyDraft {
        NaturalJourneyDraft(intent: try intent.domain(), origin: try origin?.domain(), destination: try destination?.domain())
    }
}

extension NaturalJourneyResultDTO {
    func domain() throws -> NaturalJourneyResult {
        switch self {
        case .ready(let value):
            let interpretation = value.interpretation
            guard let time = JourneyDatetimeRepresents(rawValue: interpretation.datetimeRepresents) else { throw ViaError.decoding }
            return .ready(
                answer: value.answer,
                preferenceNotice: value.preferenceNotice,
                interpretation: NaturalJourneyInterpretation(
                    originLabel: interpretation.originLabel,
                    destination: interpretation.destination.domain,
                    destinationResult: try interpretation.destinationResult.domain(),
                    requestedAt: interpretation.requestedAt,
                    datetimeRepresents: time,
                    requiredModes: Set(interpretation.requiredModes.compactMap(TransitMode.init(rawValue:))),
                    excludedModes: Set(interpretation.excludedModes.compactMap(TransitMode.init(rawValue:))),
                    preferredModes: Set(interpretation.preferredModes.compactMap(TransitMode.init(rawValue:)))
                ),
                journeys: try value.journeys.domain()
            )
        case .clarification(let value):
            return .needsClarification(
                draft: try value.draft.domain(),
                fields: try value.fields.map { field in
                    guard let target = NaturalJourneyClarification.Target(rawValue: field.target) else { throw ViaError.decoding }
                    return NaturalJourneyClarification(target: target, question: field.question, candidates: try field.candidates.map { try $0.domain() })
                }
            )
        case .unsupported(let value): return .unsupported(message: value.message, examples: value.examples ?? [])
        case .unavailable(let value): return .unavailable(message: value.message)
        case .rateLimited(let value): return .rateLimited(message: value.message)
        }
    }
}

