import Foundation
import OpenAPIRuntime

struct JourneyDepartureChoicesRequest: Sendable, Hashable {
    let journey: Journey
    let destination: JourneyDestination
    let policy: JourneyPlanningPolicy
    let selection: JourneyDepartureSelection?
}

protocol JourneyDepartureChoicesRepository: Sendable {
    func resolve(
        _ request: JourneyDepartureChoicesRequest
    ) async throws -> JourneyDepartureChoicesSnapshot
}

/// The only live entry point for departure discovery and downstream journey
/// reconstruction. Views deal exclusively in complete snapshots.
struct LiveJourneyDepartureChoicesRepository: JourneyDepartureChoicesRepository {
    let transport: APITransport

    func resolve(
        _ request: JourneyDepartureChoicesRequest
    ) async throws -> JourneyDepartureChoicesSnapshot {
        try await transport.perform("journeys.departureChoices") { client in
            typealias Payload = Operations.journeys_period_departureChoices.Input.Body.jsonPayload
            let payload = try transport.convert(
                JourneyDepartureChoicesRequestDTO(request),
                to: Payload.self
            )
            let input = Operations.journeys_period_departureChoices.Input(body: .json(payload))
            switch try await client.journeys_period_departureChoices(input) {
            case let .ok(response):
                return try transport.convert(
                    response.body.json,
                    to: JourneyDepartureChoicesResponseDTO.self
                ).domain()
            case let .undocumented(statusCode, _):
                throw APITransport.error(for: statusCode)
            }
        }
    }
}

struct InMemoryJourneyDepartureChoicesRepository: JourneyDepartureChoicesRepository {
    static let unavailable = InMemoryJourneyDepartureChoicesRepository { _ in
        throw ViaError.unavailable
    }

    let handler: @Sendable (JourneyDepartureChoicesRequest) async throws
        -> JourneyDepartureChoicesSnapshot

    init(
        handler: @escaping @Sendable (JourneyDepartureChoicesRequest) async throws
            -> JourneyDepartureChoicesSnapshot
    ) {
        self.handler = handler
    }

    init(snapshot: JourneyDepartureChoicesSnapshot) {
        handler = { _ in snapshot }
    }

    func resolve(
        _ request: JourneyDepartureChoicesRequest
    ) async throws -> JourneyDepartureChoicesSnapshot {
        try await handler(request)
    }
}

private struct JourneyDepartureChoicesRequestDTO: Encodable {
    let journey: JourneyDTO
    let destination: DestinationDTO
    let policy: PolicyDTO
    let selection: SelectionDTO?

    init(_ request: JourneyDepartureChoicesRequest) {
        journey = JourneyDTO(request.journey)
        destination = DestinationDTO(request.destination)
        policy = PolicyDTO(request.policy)
        selection = request.selection.map(SelectionDTO.init)
    }

    struct JourneyDTO: Encodable {
        let id: String
        let qualifier: Journey.Qualifier
        let durationSeconds: Int
        let walkingDurationSeconds: Int
        let transferCount: Int
        let departureAt: Date
        let arrivalAt: Date
        let status: Journey.Status
        let warnings: [String]
        let accessibility: Journey.Accessibility?
        let peak: PeakDTO?
        let reportedCrowding: Journey.ReportedCrowding?
        let wheelchairReport: Journey.WheelchairReport?
        let sections: [SectionDTO]

        init(_ journey: Journey) {
            id = journey.id.rawValue
            qualifier = journey.qualifier
            durationSeconds = journey.durationSeconds
            walkingDurationSeconds = journey.walkingDurationSeconds
            transferCount = journey.transferCount
            departureAt = journey.departureAt
            arrivalAt = journey.arrivalAt
            status = journey.status
            warnings = journey.warnings
            accessibility = journey.accessibility
            peak = journey.peak.map(PeakDTO.init)
            reportedCrowding = journey.reportedCrowding
            wheelchairReport = journey.wheelchairReport
            sections = journey.sections.map(SectionDTO.init)
        }
    }

    struct PeakDTO: Encodable {
        let ratio: Double
        let level: PeakLevel
        let stationName: String
        let label: String

        init(_ value: StationPeak) {
            ratio = value.ratio
            level = value.level
            stationName = value.stationName ?? ""
            label = value.label
        }
    }

    struct SectionDTO: Encodable {
        let id: String
        let type: JourneySection.Kind
        let durationSeconds: Int
        let from: JourneyPlace
        let to: JourneyPlace
        let departureAt: Date?
        let arrivalAt: Date?
        let scheduledDepartureAt: Date?
        let scheduledArrivalAt: Date?
        let geometry: [GeoCoordinate]
        let route: RouteDTO?
        let direction: String?
        let platform: String?
        let stops: [StopDTO]
        let serviceId: String?
        let timingSource: JourneyTimingSource?
        let departureStatus: DepartureStatus?
        let boardingPosition: JourneyBoardingPosition?
        let exit: JourneyExit?

        init(_ section: JourneySection) {
            id = section.id
            type = section.kind
            durationSeconds = section.durationSeconds
            from = section.from
            to = section.to
            departureAt = section.departureAt
            arrivalAt = section.arrivalAt
            scheduledDepartureAt = section.scheduledDepartureAt
            scheduledArrivalAt = section.scheduledArrivalAt
            geometry = section.geometry
            route = section.route.map(RouteDTO.init)
            direction = section.direction
            platform = section.platform
            stops = section.stops.map(StopDTO.init)
            serviceId = section.serviceID
            timingSource = section.timingSource
            departureStatus = section.departureStatus
            boardingPosition = section.boardingPosition
            exit = section.exit
        }
    }

    struct StopDTO: Encodable {
        let id: String
        let stationId: String?
        let name: String
        let coordinate: GeoCoordinate
        let arrivalAt: Date?
        let departureAt: Date?

        init(_ value: JourneyStop) {
            id = value.id
            stationId = value.stationID?.rawValue
            name = value.name
            coordinate = value.coordinate
            arrivalAt = value.arrivalAt
            departureAt = value.departureAt
        }
    }

    struct RouteDTO: Encodable {
        let id: String
        let shortName: String
        let longName: String
        let mode: TransitMode
        let color: String
        let textColor: String

        init(_ value: JourneyRoute) {
            id = value.id.rawValue
            shortName = value.shortName
            longName = value.longName
            mode = value.mode
            color = value.colorHex
            textColor = value.textColorHex
        }
    }

    enum DestinationDTO: Encodable {
        case station(id: String, name: String, coordinate: GeoCoordinate)
        case address(id: String, name: String, context: String?, coordinate: GeoCoordinate)

        init(_ destination: JourneyDestination) {
            switch destination {
            case let .station(id, name, coordinate):
                self = .station(id: id.rawValue, name: name, coordinate: coordinate)
            case let .address(id, name, context, coordinate):
                self = .address(id: id, name: name, context: context, coordinate: coordinate)
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case let .station(id, name, coordinate):
                try container.encode("station", forKey: .kind)
                try container.encode(id, forKey: .id)
                try container.encode(name, forKey: .name)
                try container.encode(coordinate, forKey: .coordinate)
            case let .address(id, name, context, coordinate):
                try container.encode("address", forKey: .kind)
                try container.encode(id, forKey: .id)
                try container.encode(name, forKey: .name)
                try container.encodeIfPresent(context, forKey: .context)
                try container.encode(coordinate, forKey: .coordinate)
            }
        }

        private enum CodingKeys: String, CodingKey {
            case kind, id, name, context, coordinate
        }
    }

    struct PolicyDTO: Encodable {
        let requiredModes: [TransitMode]
        let excludedModes: [TransitMode]
        let preferredModes: [TransitMode]
        let requiresAccessibleStations: Bool
        let requiresOperationalElevators: Bool

        init(_ value: JourneyPlanningPolicy) {
            requiredModes = value.requiredModes.sorted { $0.rawValue < $1.rawValue }
            excludedModes = value.excludedModes.sorted { $0.rawValue < $1.rawValue }
            preferredModes = value.preferredModes.sorted { $0.rawValue < $1.rawValue }
            requiresAccessibleStations = value.requiresAccessibleStations
            requiresOperationalElevators = value.requiresOperationalElevators
        }
    }

    struct SelectionDTO: Encodable {
        let sectionId: String
        let departureId: String

        init(_ value: JourneyDepartureSelection) {
            sectionId = value.sectionID
            departureId = value.departureID
        }
    }
}

private struct JourneyDepartureChoicesResponseDTO: Decodable {
    let journey: JourneyResultDTO.JourneyDTO
    let generatedAt: Date
    let groups: [GroupDTO]

    struct GroupDTO: Decodable {
        let sectionId: String
        let availability: String
        let source: String?
        let fetchedAt: Date?
        let choices: [ChoiceDTO]
    }

    struct ChoiceDTO: Decodable {
        let id: String
        let scheduledAt: Date?
        let expectedAt: Date?
        let status: String
        let source: String?
        let isSelected: Bool
    }

    func domain() throws -> JourneyDepartureChoicesSnapshot {
        try JourneyDepartureChoicesSnapshot(
            journey: journey.domain(),
            generatedAt: generatedAt,
            groups: groups.map { group in
                JourneyDepartureChoiceGroup(
                    sectionID: group.sectionId,
                    availability: group.availability == "ready" ? .available : .unavailable,
                    source: group.source.flatMap(JourneyTimingSource.init(rawValue:)),
                    fetchedAt: group.fetchedAt,
                    choices: group.choices.compactMap { choice in
                        guard let scheduledAt = choice.scheduledAt,
                              let status = DepartureStatus(rawValue: choice.status) else { return nil }
                        return JourneyDepartureChoice(
                            id: choice.id,
                            scheduledAt: scheduledAt,
                            expectedAt: choice.expectedAt,
                            status: status,
                            source: choice.source.flatMap(JourneyTimingSource.init(rawValue:)),
                            isSelected: choice.isSelected
                        )
                    }
                )
            }
        )
    }
}
