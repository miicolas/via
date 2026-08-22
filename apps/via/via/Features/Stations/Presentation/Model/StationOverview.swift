import Foundation

struct StationDeparture: Sendable, Hashable, Identifiable {
    let id: String
    let route: RouteBadge
    let destination: String
    let scheduledAt: Date?
    let departureAt: Date?
    let delaySeconds: Int?
    let status: DepartureStatus

    init(
        id: String,
        route: RouteBadge,
        destination: String,
        scheduledAt: Date?,
        expectedAt: Date?,
        delaySeconds: Int?,
        status: DepartureStatus
    ) {
        self.id = id
        self.route = route
        self.destination = destination
        self.scheduledAt = scheduledAt
        self.departureAt = expectedAt ?? scheduledAt
        self.delaySeconds = delaySeconds
        self.status = status
    }

    init(route: RouteBadge, destination: String, departureAt: Date) {
        self.init(
            id: "legacy-\(route.id.rawValue)-\(destination)-\(departureAt.timeIntervalSince1970)",
            route: route,
            destination: destination,
            scheduledAt: departureAt,
            expectedAt: nil,
            delaySeconds: nil,
            status: .noReport
        )
    }
}

struct StationOverview: Sendable, Hashable, Identifiable {
    let id: StationID
    let name: String
    let coordinate: GeoCoordinate
    let routes: [RouteBadge]
    let accessibility: StationAccessibility?
    let distanceMeters: Double?
    let departures: [StationDeparture]
    let departureSource: DepartureBoard.Source
    let departureFetchedAt: Date?
    let peak: StationPeak?

    init(
        id: StationID,
        name: String,
        coordinate: GeoCoordinate,
        routes: [RouteBadge],
        accessibility: StationAccessibility? = nil,
        distanceMeters: Double?,
        departures: [StationDeparture],
        departureSource: DepartureBoard.Source,
        departureFetchedAt: Date? = nil,
        peak: StationPeak? = nil
    ) {
        self.id = id
        self.name = name
        self.coordinate = coordinate
        self.routes = routes
        self.accessibility = accessibility
        self.distanceMeters = distanceMeters
        self.departures = departures
        self.departureSource = departureSource
        self.departureFetchedAt = departureFetchedAt
        self.peak = peak
    }

    var primaryMode: TransitMode {
        routes.first?.mode ?? .metro
    }

    var distanceText: String? {
        guard let distanceMeters else { return nil }
        return DistanceFormatting.text(meters: distanceMeters)
    }

    /// The feed, named only when there is something to say about it: live, or
    /// missing. A schedule board simply shows its times.
    var sourceText: String? {
        switch departureSource {
        case .realtime:
            "Temps réel"
        case .theoretical:
            nil
        case .unavailable:
            "Horaires indisponibles"
        }
    }

    /// The glyph that goes with `sourceText`, so the live line never wears the
    /// clock the schedule used to.
    var sourceSystemImage: String {
        switch departureSource {
        case .realtime: "dot.radiowaves.up.forward"
        case .theoretical, .unavailable: "wifi.slash"
        }
    }

    func departures(for route: RouteBadge) -> [StationDeparture] {
        departures.filter { $0.route.id == route.id }
    }
}

extension StationOverview {
    static let preview: Self = {
        let metro1 = RouteBadge(
            id: RouteID(rawValue: "preview:metro:1"),
            shortName: "1",
            mode: .metro,
            colorHex: "#FFCD00",
            textColorHex: "#000000"
        )
        let metro4 = RouteBadge(
            id: RouteID(rawValue: "preview:metro:4"),
            shortName: "4",
            mode: .metro,
            colorHex: "#B42C91",
            textColorHex: "#FFFFFF"
        )
        let metro11 = RouteBadge(
            id: RouteID(rawValue: "preview:metro:11"),
            shortName: "11",
            mode: .metro,
            colorHex: "#8D5E2A",
            textColorHex: "#FFFFFF"
        )
        let now = Date.now

        return Self(
            id: StationID(rawValue: "preview:chatelet"),
            name: "Châtelet",
            coordinate: GeoCoordinate(latitude: 48.8583, longitude: 2.3470),
            routes: [metro1, metro4, metro11],
            accessibility: StationAccessibility(
                condition: .autonomous,
                label: "En autonomie",
                comment: nil
            ),
            distanceMeters: 250,
            departures: [
                StationDeparture(
                    id: "preview-delayed",
                    route: metro1,
                    destination: "La Défense",
                    scheduledAt: now.addingTimeInterval(2 * 60),
                    expectedAt: now.addingTimeInterval(4 * 60),
                    delaySeconds: 120,
                    status: .delayed
                ),
                StationDeparture(
                    route: metro4,
                    destination: "Bagneux",
                    departureAt: now.addingTimeInterval(7 * 60)
                ),
                StationDeparture(
                    route: metro11,
                    destination: "Mairie des Lilas",
                    departureAt: now.addingTimeInterval(12 * 60)
                ),
            ],
            departureSource: .realtime,
            departureFetchedAt: now.addingTimeInterval(-18)
        )
    }()
}
