import Foundation
import OpenAPIRuntime

struct JourneyShareLink: Sendable, Hashable, Identifiable {
    let url: URL
    let expiresAt: Date

    var id: String { url.absoluteString }
}

struct JourneyShareSnapshot: Sendable, Hashable {
    let journey: Journey
    let generatedAt: Date
    let locale: String
    let timeZone: String
    let expiresAt: Date
}

protocol JourneyShareRepository: Sendable {
    func create(for journey: Journey) async throws -> JourneyShareLink
    func load(token: String) async throws -> JourneyShareSnapshot
}

struct LiveJourneyShareRepository: JourneyShareRepository {
    let transport: APITransport

    func create(for journey: Journey) async throws -> JourneyShareLink {
        try await transport.perform("journeyShares.create") { client in
            typealias Payload = Operations.journeyShares_period_create.Input.Body.jsonPayload
            let payload = try transport.convert(
                JourneyShareCreateRequestDTO(journey: journey),
                to: Payload.self
            )
            let input = Operations.journeyShares_period_create.Input(body: .json(payload))

            switch try await client.journeyShares_period_create(input) {
            case let .ok(response):
                let dto = try transport.convert(
                    response.body.json,
                    to: JourneyShareCreateResponseDTO.self
                )
                guard
                    let url = URL(string: dto.url),
                    url.scheme?.lowercased() == "https"
                else {
                    throw ViaError.decoding
                }
                return JourneyShareLink(url: url, expiresAt: dto.expiresAt)
            case let .undocumented(statusCode, _):
                throw APITransport.error(for: statusCode)
            }
        }
    }

    func load(token: String) async throws -> JourneyShareSnapshot {
        try await transport.perform("journeyShares.get") { client in
            let input = Operations.journeyShares_period_get.Input(
                query: .init(token: token)
            )

            switch try await client.journeyShares_period_get(input) {
            case let .ok(response):
                return try transport.convert(
                    response.body.json,
                    to: JourneyShareResponseDTO.self
                ).domain()
            case let .undocumented(statusCode, _):
                throw APITransport.error(for: statusCode)
            }
        }
    }
}

/// The preview keeps the share action exercisable without making a network
/// request. Production always uses `LiveJourneyShareRepository`.
struct InMemoryJourneyShareRepository: JourneyShareRepository {
    private static let previewURL = ShareLinkOrigin.url(
        token: String(repeating: "A", count: 43)
    )

    func create(for journey: Journey) async throws -> JourneyShareLink {
        JourneyShareLink(url: Self.previewURL, expiresAt: .distantFuture)
    }

    func load(token: String) async throws -> JourneyShareSnapshot {
        throw ViaError.unavailable
    }
}

private struct JourneyShareCreateRequestDTO: Encodable {
    let snapshot: JourneyShareSnapshotDTO
    let idempotencyKey: String

    init(journey: Journey) {
        snapshot = JourneyShareSnapshotDTO(journey: journey)
        idempotencyKey = UUID().uuidString.lowercased()
    }
}

private struct JourneyShareSnapshotDTO: Codable {
    let schemaVersion: Int
    let journey: JourneyWireDTO
    let generatedAt: Date
    let locale: String
    let timeZone: String

    init(journey: Journey) {
        schemaVersion = 1
        self.journey = JourneyWireDTO(journey)
        generatedAt = .now
        locale = Locale.current.identifier
        timeZone = TimeZone.current.identifier
    }

    func domain(expiresAt: Date) throws -> JourneyShareSnapshot {
        guard schemaVersion == 1 else { throw ViaError.decoding }
        return JourneyShareSnapshot(
            journey: try journey.domain(),
            generatedAt: generatedAt,
            locale: locale,
            timeZone: timeZone,
            expiresAt: expiresAt
        )
    }
}

/// Only the fields the app acts on are declared: `Decodable` ignores the rest,
/// and a property nobody reads reads as part of the contract when it is not.
private struct JourneyShareResponseDTO: Decodable {
    let snapshot: JourneyShareSnapshotDTO
    let expiresAt: Date

    func domain() throws -> JourneyShareSnapshot {
        try snapshot.domain(expiresAt: expiresAt)
    }
}

private struct JourneyShareCreateResponseDTO: Decodable {
    let expiresAt: Date
    let url: String
}

/// The app's domain model is intentionally ergonomic (`kind`, `colorHex`,
/// wrapper IDs). The API contract is a public JSON projection (`type`, `color`,
/// string IDs), so this bridge keeps that translation in the data layer.
private struct JourneyWireDTO: Codable {
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

    func domain() throws -> Journey {
        guard !sections.isEmpty else { throw ViaError.decoding }
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
            accessibility: accessibility,
            peak: peak?.domain,
            reportedCrowding: reportedCrowding,
            wheelchairReport: wheelchairReport,
            sections: sections.enumerated().map { index, section in
                section.domain(id: "\(id):\(index)")
            }
        )
    }

    struct PeakDTO: Codable {
        let ratio: Double
        let level: PeakLevel
        let stationId: String?
        let stationName: String
        let label: String

        init(_ value: StationPeak) {
            ratio = value.ratio
            level = value.level
            stationId = nil
            stationName = value.stationName ?? ""
            label = value.label
        }

        var domain: StationPeak {
            StationPeak(
                ratio: ratio,
                level: level,
                label: label,
                stationName: stationName.isEmpty ? nil : stationName
            )
        }
    }

    struct SectionDTO: Codable {
        let id: String?
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
        let stops: [StopDTO]?
        let serviceId: String?
        let timingSource: JourneyTimingSource?
        let departureStatus: DepartureStatus?
        let boardingPosition: JourneyBoardingPosition?
        let exit: JourneyExit?

        init(_ value: JourneySection) {
            id = value.id
            type = value.kind
            durationSeconds = value.durationSeconds
            from = value.from
            to = value.to
            departureAt = value.departureAt
            arrivalAt = value.arrivalAt
            scheduledDepartureAt = value.scheduledDepartureAt
            scheduledArrivalAt = value.scheduledArrivalAt
            geometry = value.geometry
            route = value.route.map(RouteDTO.init)
            direction = value.direction
            platform = value.platform
            stops = value.stops.map(StopDTO.init)
            serviceId = value.serviceID
            timingSource = value.timingSource
            departureStatus = value.departureStatus
            boardingPosition = value.boardingPosition
            exit = value.exit
        }

        func domain(id fallbackID: String) -> JourneySection {
            JourneySection(
                id: id ?? fallbackID,
                serviceID: serviceId,
                timingSource: timingSource,
                departureStatus: departureStatus,
                kind: type,
                durationSeconds: durationSeconds,
                from: from,
                to: to,
                departureAt: departureAt,
                arrivalAt: arrivalAt,
                scheduledDepartureAt: scheduledDepartureAt,
                scheduledArrivalAt: scheduledArrivalAt,
                geometry: geometry,
                route: route?.domain,
                direction: direction,
                platform: platform,
                stops: (stops ?? []).map(\.domain),
                boardingPosition: boardingPosition,
                exit: exit
            )
        }

        struct StopDTO: Codable {
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

            var domain: JourneyStop {
                JourneyStop(
                    id: id,
                    stationID: stationId.map(StationID.init(rawValue:)),
                    name: name,
                    coordinate: coordinate,
                    arrivalAt: arrivalAt,
                    departureAt: departureAt
                )
            }
        }

        struct RouteDTO: Codable {
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

            var domain: JourneyRoute {
                JourneyRoute(
                    id: RouteID(rawValue: id),
                    shortName: shortName,
                    longName: longName,
                    mode: mode,
                    colorHex: color,
                    textColorHex: textColor
                )
            }
        }
    }
}
