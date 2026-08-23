import Foundation

enum DepartureStatus: String, Codable, Sendable, Hashable {
    case onTime = "on_time"
    case delayed
    case early
    case cancelled
    case missed
    case arrived
    case departed
    case noReport = "no_report"
    case scheduled

    var isHiddenFromBoard: Bool {
        self == .arrived || self == .departed
    }
}

struct DepartureItem: Sendable, Hashable, Identifiable {
    let id: String
    let scheduledAt: Date?
    let expectedAt: Date?
    let delaySeconds: Int?
    let status: DepartureStatus

    var displayAt: Date? { expectedAt ?? scheduledAt }
}

struct DepartureGroup: Sendable, Hashable, Identifiable {
    let route: RouteBadge
    let destination: String
    let departures: [Date]
    let departureItems: [DepartureItem]

    init(
        route: RouteBadge,
        destination: String,
        departures: [Date],
        status: DepartureStatus = .noReport
    ) {
        self.route = route
        self.destination = destination
        self.departures = departures
        self.departureItems = departures.enumerated().map { index, date in
            DepartureItem(
                id: "legacy-\(route.id.rawValue)-\(destination)-\(index)-\(date.timeIntervalSince1970)",
                scheduledAt: date,
                expectedAt: nil,
                delaySeconds: nil,
                status: status
            )
        }
    }

    init(route: RouteBadge, destination: String, departureItems: [DepartureItem]) {
        self.route = route
        self.destination = destination
        self.departureItems = departureItems
        self.departures = departureItems.compactMap(\.displayAt)
    }

    var id: String { "\(route.id.rawValue):\(destination)" }
}

struct DepartureBoard: Sendable, Hashable {
    enum Source: String, Sendable, Hashable { case realtime, theoretical, unavailable }

    let source: Source
    let generatedAt: Date
    let fetchedAt: Date?
    let peak: StationPeak?
    let elevators: StationElevatorSnapshot
    let groups: [DepartureGroup]

    init(
        source: Source,
        generatedAt: Date,
        fetchedAt: Date? = nil,
        peak: StationPeak? = nil,
        elevators: StationElevatorSnapshot = .unavailable,
        groups: [DepartureGroup]
    ) {
        self.source = source
        self.generatedAt = generatedAt
        self.fetchedAt = fetchedAt
        self.peak = peak
        self.elevators = elevators
        self.groups = groups
    }
}
