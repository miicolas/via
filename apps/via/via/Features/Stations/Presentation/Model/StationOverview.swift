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

    /// A passage the traveller can actually board, at a time Via knows. Anything
    /// else — cancelled, not served, timeless — is an exception the timetable
    /// prints on a row of its own, rather than folding it into a cadence that
    /// would claim it runs.
    var isBoardable: Bool {
        departureAt != nil && status != .cancelled && status != .missed
    }
}

struct StationOverview: Sendable, Hashable, Identifiable {
    let id: StationID
    let name: String
    let coordinate: GeoCoordinate
    let routes: [RouteBadge]
    let accessibility: StationAccessibility?
    let toilets: StationToilets?
    let fountains: StationFountains?
    let distanceMeters: Double?
    /// One representative passage per direction, used by the compact station
    /// row in the Stations tab.
    let departures: [StationDeparture]
    /// Every upcoming passage returned by the board, used by the station detail.
    /// Keeping this separate prevents the compact row from losing the rest of
    /// the board just because it only has room for one passage per direction.
    let departureBoard: [StationDeparture]
    let departureSource: DepartureBoard.Source
    let departureFetchedAt: Date?
    let peak: StationPeak?
    let elevators: StationElevatorSnapshot

    init(
        id: StationID,
        name: String,
        coordinate: GeoCoordinate,
        routes: [RouteBadge],
        accessibility: StationAccessibility? = nil,
        toilets: StationToilets? = nil,
        fountains: StationFountains? = nil,
        distanceMeters: Double?,
        departures: [StationDeparture],
        departureSource: DepartureBoard.Source,
        departureFetchedAt: Date? = nil,
        peak: StationPeak? = nil,
        elevators: StationElevatorSnapshot = .unavailable,
        departureBoard: [StationDeparture]? = nil
    ) {
        self.id = id
        self.name = name
        self.coordinate = coordinate
        self.routes = routes
        self.accessibility = accessibility
        self.toilets = toilets
        self.fountains = fountains
        self.distanceMeters = distanceMeters
        self.departures = departures
        self.departureBoard = departureBoard ?? departures
        self.departureSource = departureSource
        self.departureFetchedAt = departureFetchedAt
        self.peak = peak
        self.elevators = elevators
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
            toilets: StationToilets(
                label: "Sanitaires disponibles",
                detail: "Accès gratuit · Accessible PMR\nÀ proximité de la sortie 3."
            ),
            fountains: StationFountains(
                status: .available,
                label: "Fontaine d’eau potable à proximité",
                detail: "Accessible PMR · Remplissage de gourde possible"
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
