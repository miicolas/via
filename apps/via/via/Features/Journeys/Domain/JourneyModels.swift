import Foundation

enum JourneyDestination: Codable, Sendable, Hashable {
    case station(id: StationID, name: String, coordinate: GeoCoordinate)
    case address(id: String, name: String, context: String?, coordinate: GeoCoordinate)

    var coordinate: GeoCoordinate {
        switch self {
        case .station(_, _, let coordinate), .address(_, _, _, let coordinate): coordinate
        }
    }

    var name: String {
        switch self {
        case .station(_, let name, _), .address(_, let name, _, _): name
        }
    }
}

enum JourneyDatetimeRepresents: String, Codable, Sendable, Hashable, Identifiable {
    case departure
    case arrival

    var id: Self { self }
}

/// « Le dernier train » : the server plans against the end of the service day,
/// verified on the GTFS timetable, instead of an instant.
enum JourneyTimeAnchor: String, Codable, Sendable, Hashable {
    case lastOfDay = "last_of_day"
}

struct JourneyRequest: Sendable, Hashable {
    let origin: GeoCoordinate
    let destination: JourneyDestination
    var limit = 4
    var requestedAt: Date?
    var datetimeRepresents: JourneyDatetimeRepresents?
    var timeAnchor: JourneyTimeAnchor?
    var requiredModes: Set<TransitMode> = []
    var excludedModes: Set<TransitMode> = []
    var preferredModes: Set<TransitMode> = []
    var requiresAccessibleStations = false
    var requiresOperationalElevators = false
    var originStationID: StationID?

    init(origin: GeoCoordinate, destination: JourneyDestination) {
        self.init(origin: origin, destination: destination, policy: JourneyPlanningPolicy())
    }

    init(
        origin: GeoCoordinate,
        destination: JourneyDestination,
        policy: JourneyPlanningPolicy,
        limit: Int = 4,
        requestedAt: Date? = nil,
        datetimeRepresents: JourneyDatetimeRepresents? = nil,
        timeAnchor: JourneyTimeAnchor? = nil,
        originStationID: StationID? = nil
    ) {
        self.origin = origin
        self.destination = destination
        self.limit = limit
        self.requestedAt = requestedAt
        self.datetimeRepresents = datetimeRepresents
        self.timeAnchor = timeAnchor
        self.requiredModes = policy.requiredModes
        self.excludedModes = policy.excludedModes
        self.preferredModes = policy.preferredModes
        self.requiresAccessibleStations = policy.requiresAccessibleStations
        self.requiresOperationalElevators = policy.requiresOperationalElevators
        self.originStationID = originStationID
    }
}

struct JourneyPlace: Codable, Sendable, Hashable {
    let name: String
    let coordinate: GeoCoordinate
}

struct JourneyStop: Codable, Sendable, Hashable, Identifiable {
    let id: String
    /// Stable parent station reference used to reconcile Journey and Departures.
    let stationID: StationID?
    let name: String
    let coordinate: GeoCoordinate
    let arrivalAt: Date?
    let departureAt: Date?

    init(
        id: String,
        stationID: StationID? = nil,
        name: String,
        coordinate: GeoCoordinate,
        arrivalAt: Date?,
        departureAt: Date?
    ) {
        self.id = id
        self.stationID = stationID
        self.name = name
        self.coordinate = coordinate
        self.arrivalAt = arrivalAt
        self.departureAt = departureAt
    }
}

enum JourneyTimingSource: String, Codable, Sendable, Hashable {
    case realtime
    case theoretical
}

struct JourneyRoute: Codable, Sendable, Hashable, Identifiable {
    let id: RouteID
    let shortName: String
    let longName: String
    let mode: TransitMode
    let colorHex: String
    let textColorHex: String
}

/// Where to stand on the platform so the doors open in front of what comes next.
///
/// `car` counts from the head of the train in its direction of travel, so the
/// advice belongs to the section that carries it and to no other. `carCount` is
/// the line's nominal train length: a short trainset makes the number
/// optimistic, which is why the interface leads with `zone`.
struct JourneyBoardingPosition: Codable, Sendable, Hashable {
    enum Zone: String, Codable, Sendable, Hashable { case front, middle, rear }
    enum Reason: String, Codable, Sendable, Hashable { case exit, transfer }
    enum Equipment: String, Codable, Sendable, Hashable { case escalator, lift, stairs }

    let car: Int
    let carCount: Int
    let zone: Zone
    let reason: Reason
    let equipment: Equipment?
}

/// The station exit nearest the destination, named as its signage names it.
struct JourneyExit: Codable, Sendable, Hashable, Identifiable {
    let id: String
    let name: String
    let number: Int?
    let coordinate: GeoCoordinate
    let walkingMeters: Int?
}

struct JourneySection: Codable, Sendable, Hashable, Identifiable {
    enum Kind: String, Codable, Sendable, Hashable { case walk, bike, wait, transfer, transit }

    let id: String
    /// Opaque circulation reference. It is round-tripped, never interpreted on-device.
    let serviceID: String?
    let timingSource: JourneyTimingSource?
    let departureStatus: DepartureStatus?
    let kind: Kind
    let durationSeconds: Int
    let from: JourneyPlace
    let to: JourneyPlace
    let departureAt: Date?
    let arrivalAt: Date?
    let scheduledDepartureAt: Date?
    let scheduledArrivalAt: Date?
    let geometry: [GeoCoordinate]
    let route: JourneyRoute?
    let direction: String?
    let platform: String?
    let stops: [JourneyStop]
    /// Followed when boarding, decided by where this section ends.
    let boardingPosition: JourneyBoardingPosition?
    /// Only ever on the last transit section — where to leave the network.
    let exit: JourneyExit?

    init(
        id: String,
        serviceID: String? = nil,
        timingSource: JourneyTimingSource? = nil,
        departureStatus: DepartureStatus? = nil,
        kind: Kind,
        durationSeconds: Int,
        from: JourneyPlace,
        to: JourneyPlace,
        departureAt: Date?,
        arrivalAt: Date?,
        scheduledDepartureAt: Date? = nil,
        scheduledArrivalAt: Date? = nil,
        geometry: [GeoCoordinate],
        route: JourneyRoute?,
        direction: String?,
        platform: String?,
        stops: [JourneyStop],
        boardingPosition: JourneyBoardingPosition? = nil,
        exit: JourneyExit? = nil
    ) {
        self.id = id
        self.serviceID = serviceID
        self.timingSource = timingSource
        self.departureStatus = departureStatus
        self.kind = kind
        self.durationSeconds = durationSeconds
        self.from = from
        self.to = to
        self.departureAt = departureAt
        self.arrivalAt = arrivalAt
        self.scheduledDepartureAt = scheduledDepartureAt
        self.scheduledArrivalAt = scheduledArrivalAt
        self.geometry = geometry
        self.route = route
        self.direction = direction
        self.platform = platform
        self.stops = stops
        self.boardingPosition = boardingPosition
        self.exit = exit
    }
}

/// The calculation context that must survive from search into guidance so a
/// departure revision can rebuild the downstream journey with the same rules.
struct JourneyPlanningPolicy: Codable, Sendable, Hashable {
    var requiredModes: Set<TransitMode> = []
    var excludedModes: Set<TransitMode> = []
    var preferredModes: Set<TransitMode> = []
    var requiresAccessibleStations = false
    var requiresOperationalElevators = false

    private enum CodingKeys: String, CodingKey {
        case requiredModes
        case excludedModes
        case preferredModes
        case requiresAccessibleStations
        case requiresOperationalElevators
    }

    init(
        requiredModes: Set<TransitMode> = [],
        excludedModes: Set<TransitMode> = [],
        preferredModes: Set<TransitMode> = [],
        requiresAccessibleStations: Bool = false,
        requiresOperationalElevators: Bool = false
    ) {
        self.requiredModes = requiredModes
        self.excludedModes = excludedModes
        self.preferredModes = preferredModes
        self.requiresAccessibleStations = requiresAccessibleStations
        self.requiresOperationalElevators = requiresOperationalElevators
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        requiredModes = try values.decodeIfPresent(Set<TransitMode>.self, forKey: .requiredModes) ?? []
        excludedModes = try values.decodeIfPresent(Set<TransitMode>.self, forKey: .excludedModes) ?? []
        preferredModes = try values.decodeIfPresent(Set<TransitMode>.self, forKey: .preferredModes) ?? []
        requiresAccessibleStations = try values.decodeIfPresent(
            Bool.self,
            forKey: .requiresAccessibleStations
        ) ?? false
        requiresOperationalElevators = try values.decodeIfPresent(
            Bool.self,
            forKey: .requiresOperationalElevators
        ) ?? false
    }
}

struct JourneyDepartureSelection: Codable, Sendable, Hashable {
    let sectionID: String
    let departureID: String
}

struct JourneyDepartureChoice: Sendable, Hashable, Identifiable {
    let id: String
    let scheduledAt: Date
    let expectedAt: Date?
    let status: DepartureStatus
    let source: JourneyTimingSource?
    let isSelected: Bool

    var displayAt: Date { expectedAt ?? scheduledAt }

    init(
        id: String,
        scheduledAt: Date,
        expectedAt: Date?,
        status: DepartureStatus,
        source: JourneyTimingSource? = nil,
        isSelected: Bool
    ) {
        self.id = id
        self.scheduledAt = scheduledAt
        self.expectedAt = expectedAt
        self.status = status
        self.source = source
        self.isSelected = isSelected
    }
}

struct JourneyDepartureChoiceGroup: Sendable, Hashable, Identifiable {
    enum Availability: String, Sendable, Hashable {
        case available
        case unavailable
    }

    let sectionID: String
    let availability: Availability
    let source: JourneyTimingSource?
    let fetchedAt: Date?
    let choices: [JourneyDepartureChoice]

    var id: String { sectionID }
}

struct JourneyDepartureChoicesSnapshot: Sendable, Hashable {
    let journey: Journey
    let generatedAt: Date
    let groups: [JourneyDepartureChoiceGroup]
}

struct Journey: Codable, Sendable, Hashable, Identifiable {
    enum Qualifier: String, Codable, Sendable, Hashable {
        case recommended
        case rapid
        case lessWalking = "less-walking"
        case comfort
        case walking
        case bike
    }

    enum Status: String, Codable, Sendable, Hashable { case normal, disrupted, theoretical }

    struct Accessibility: Codable, Sendable, Hashable {
        typealias Condition = AccessibilityCondition

        let condition: Condition
        let label: String
    }

    struct ReportedCrowding: Codable, Sendable, Hashable {
        let level: CrowdingLevel
        let stationName: String
        let label: String
        let reporterCount: Int
        let expiresAt: Date
    }

    struct WheelchairReport: Codable, Sendable, Hashable {
        let stationName: String
        let label: String
        let reporterCount: Int
        let confidence: ReportConfidence
        let expiresAt: Date
    }

    let id: JourneyID
    let qualifier: Qualifier
    let durationSeconds: Int
    let walkingDurationSeconds: Int
    let transferCount: Int
    let departureAt: Date
    let arrivalAt: Date
    let status: Status
    let warnings: [String]
    let accessibility: Accessibility?
    let peak: StationPeak?
    let reportedCrowding: ReportedCrowding?
    let wheelchairReport: WheelchairReport?
    let sections: [JourneySection]

    init(
        id: JourneyID,
        qualifier: Qualifier,
        durationSeconds: Int,
        walkingDurationSeconds: Int,
        transferCount: Int,
        departureAt: Date,
        arrivalAt: Date,
        status: Status,
        warnings: [String],
        accessibility: Accessibility? = nil,
        peak: StationPeak? = nil,
        reportedCrowding: ReportedCrowding? = nil,
        wheelchairReport: WheelchairReport? = nil,
        sections: [JourneySection]
    ) {
        self.id = id
        self.qualifier = qualifier
        self.durationSeconds = durationSeconds
        self.walkingDurationSeconds = walkingDurationSeconds
        self.transferCount = transferCount
        self.departureAt = departureAt
        self.arrivalAt = arrivalAt
        self.status = status
        self.warnings = warnings
        self.accessibility = accessibility
        self.peak = peak
        self.reportedCrowding = reportedCrowding
        self.wheelchairReport = wheelchairReport
        self.sections = sections
    }
}

enum JourneyScheduleRevisionError: LocalizedError, Sendable {
    case noRoute
    case unavailable

    var errorDescription: String? {
        switch self {
        case .noRoute:
            "Aucun trajet ne correspond à cet horaire."
        case .unavailable:
            "Les horaires ne sont pas disponibles pour le moment."
        }
    }
}

extension Journey {
    /// A schedule search returns a new planner identity. The detail sheet,
    /// reminders and active draft deliberately keep the identity the traveller
    /// opened while adopting every freshly planned section and time.
    func identified(as id: JourneyID) -> Journey {
        Journey(
            id: id,
            qualifier: qualifier,
            durationSeconds: durationSeconds,
            walkingDurationSeconds: walkingDurationSeconds,
            transferCount: transferCount,
            departureAt: departureAt,
            arrivalAt: arrivalAt,
            status: status,
            warnings: warnings,
            accessibility: accessibility,
            peak: peak,
            reportedCrowding: reportedCrowding,
            wheelchairReport: wheelchairReport,
            sections: sections
        )
    }

    /// The line the traveller really follows on section `index` — what the map
    /// draws, and what a location fix is projected onto.
    ///
    /// The planner starts the walk out of the network at the alighting stop,
    /// which is a platform coordinate. The traveller surfaces at the
    /// recommended exit — the marker the map already puts there in place of the
    /// alighting one — so the walk leaves from that exit instead of from a
    /// point underground.
    func path(at index: Int) -> [GeoCoordinate] {
        guard sections.indices.contains(index) else { return [] }
        let section = sections[index]
        let planned = section.geometry.count >= 2
            ? section.geometry
            : [section.from.coordinate, section.to.coordinate]

        guard section.kind == .walk,
              index > 0,
              let exit = sections[index - 1].exit
        else { return planned }

        return [exit.coordinate] + planned.dropFirst()
    }
}

struct JourneyResult: Sendable, Hashable {
    enum Status: String, Sendable, Hashable { case ready, noRoute = "no-route", unavailable }
    enum Source: String, Codable, Sendable, Hashable { case realtime = "idfm-realtime", theoretical = "gtfs-theoretical" }
    enum Reason: String, Sendable, Hashable {
        case noAccessibleRoute = "no-accessible-route"
        case accessibilityDataUnavailable = "accessibility-data-unavailable"
        case noOperationalElevatorRoute = "no-operational-elevator-route"
        case elevatorDataUnavailable = "elevator-data-unavailable"
        /// The transit planner itself did not answer. Produced on the device,
        /// never on the wire: it is what a walking or cycling fallback carries
        /// so the screen can say the ride is missing rather than pass the walk
        /// off as the plan.
        case transitUnavailable = "transit-unavailable"
    }

    let status: Status
    let source: Source?
    let generatedAt: Date
    let journeys: [Journey]
    let reason: Reason?

    init(
        status: Status,
        source: Source?,
        generatedAt: Date,
        journeys: [Journey],
        reason: Reason? = nil
    ) {
        self.status = status
        self.source = source
        self.generatedAt = generatedAt
        self.journeys = journeys
        self.reason = reason
    }
}
