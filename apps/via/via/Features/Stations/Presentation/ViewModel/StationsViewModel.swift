import Foundation
import Observation

enum StationsViewState: Sendable, Equatable {
    case idle
    case locating
    case loading(previous: StationOverview?)
    case loaded(StationOverview)
    case empty
    case locationUnavailable(LocationAuthorization)
    case failed(ViaError, previous: StationOverview?)

    var overview: StationOverview? {
        switch self {
        case .loaded(let overview): overview
        case .loading(let previous), .failed(_, let previous): previous
        case .idle, .locating, .empty, .locationUnavailable: nil
        }
    }
}

struct StationCandidate: Sendable, Hashable {
    let station: NetworkStation
    let routes: [RouteBadge]
    let distanceMeters: Double
}

enum StationOverviewBuilder {
    private struct DepartureKey: Hashable {
        let routeID: RouteID
        let destination: String
    }

    static func nearestStation(
        in area: StationsArea,
        to location: GeoCoordinate
    ) -> StationCandidate? {
        let routeCatalog = StationRouteCatalog(routes: area.routes)

        return area.stations.compactMap { station in
            let routes = routeCatalog.routes(for: station.routeIDs)

            guard !routes.isEmpty else { return nil }

            return StationCandidate(
                station: station,
                routes: routes,
                distanceMeters: station.coordinate.metersAway(from: location)
            )
        }
        .min { lhs, rhs in lhs.distanceMeters < rhs.distanceMeters }
    }

    static func makeOverview(
        from candidate: StationCandidate,
        board: DepartureBoard,
        now: Date
    ) -> StationOverview {
        StationOverview(
            id: candidate.station.id,
            name: candidate.station.name,
            coordinate: candidate.station.coordinate,
            routes: candidate.routes,
            distanceMeters: candidate.distanceMeters,
            departures: nextDepartures(
                from: board,
                routes: candidate.routes,
                now: now
            ),
            departureSource: board.source,
            departureFetchedAt: board.fetchedAt
        )
    }

    static func nextDepartures(
        from board: DepartureBoard,
        routes: [RouteBadge],
        now: Date
    ) -> [StationDeparture] {
        var earliestByDirection: [DepartureKey: StationDeparture] = [:]
        var directionOrder: [DepartureKey] = []

        for group in board.groups {
            guard routes.contains(where: { $0.id == group.route.id }) else { continue }

            let route = routes.first(where: { $0.id == group.route.id }) ?? group.route
            let items = group.departureItems.filter { item in
                guard !item.status.isHiddenFromBoard else { return false }
                guard let displayAt = item.displayAt else {
                    return item.status == .cancelled || item.status == .missed
                }
                return displayAt >= now || item.status == .cancelled || item.status == .missed
            }

            guard let item = items.min(by: { lhs, rhs in isEarlier(lhs, than: rhs) }) else {
                continue
            }
            let key = DepartureKey(routeID: route.id, destination: group.destination)
            let departure = StationDeparture(
                id: item.id,
                route: route,
                destination: group.destination,
                scheduledAt: item.scheduledAt,
                expectedAt: item.expectedAt,
                delaySeconds: item.delaySeconds,
                status: item.status
            )

            if earliestByDirection[key] == nil {
                directionOrder.append(key)
            }

            if let current = earliestByDirection[key], !isEarlier(departure, than: current) {
                continue
            }
            earliestByDirection[key] = departure
        }

        return routes.flatMap { route in
            directionOrder
                .filter { $0.routeID == route.id }
                .compactMap { earliestByDirection[$0] }
        }
    }

    private static func isEarlier(
        _ lhs: DepartureItem,
        than rhs: DepartureItem
    ) -> Bool {
        switch (lhs.displayAt, rhs.displayAt) {
        case let (lhs?, rhs?):
            return lhs < rhs
        case (nil, _?):
            return false
        case (_?, nil):
            return true
        case (nil, nil):
            return false
        }
    }

    private static func isEarlier(
        _ lhs: StationDeparture,
        than rhs: StationDeparture
    ) -> Bool {
        switch (lhs.departureAt, rhs.departureAt) {
        case let (lhs?, rhs?):
            return lhs < rhs
        case (nil, _?):
            return false
        case (_?, nil):
            return true
        case (nil, nil):
            return false
        }
    }
}

@MainActor
@Observable
final class StationsViewModel {
    private(set) var state: StationsViewState = .idle

    @ObservationIgnored private let locationModel: LocationModel
    @ObservationIgnored private let networkRepository: any NetworkRepository
    @ObservationIgnored private let departuresRepository: any DeparturesRepository
    @ObservationIgnored private let now: @Sendable () -> Date
    @ObservationIgnored private var loadTask: Task<Void, Never>?
    @ObservationIgnored private var lastOverview: StationOverview?
    @ObservationIgnored private var stationCandidate: StationCandidate?
    @ObservationIgnored private var refreshGeneration = 0
    @ObservationIgnored private var hasStarted = false

    init(
        locationAdapter: any LocationAdapter,
        networkRepository: any NetworkRepository,
        departuresRepository: any DeparturesRepository,
        now: @escaping @Sendable () -> Date = { .now }
    ) {
        self.locationModel = LocationModel(adapter: locationAdapter)
        self.networkRepository = networkRepository
        self.departuresRepository = departuresRepository
        self.now = now
        self.locationModel.onStateChange = { [weak self] state in
            self?.handle(state)
        }
    }

    init(
        locationModel: LocationModel,
        networkRepository: any NetworkRepository,
        departuresRepository: any DeparturesRepository,
        now: @escaping @Sendable () -> Date = { .now }
    ) {
        self.locationModel = locationModel
        self.networkRepository = networkRepository
        self.departuresRepository = departuresRepository
        self.now = now
        self.locationModel.onStateChange = { [weak self] state in
            self?.handle(state)
        }
    }

    func loadIfNeeded() {
        guard !hasStarted else { return }
        hasStarted = true
        requestLocation()
    }

    func retry() {
        hasStarted = true
        requestLocation()
    }

    func refresh() async {
        hasStarted = true
        requestLocation()
        await loadTask?.value
    }

    /// Keeps the current station's departure board fresh while the screen is active.
    /// The view owns the surrounding task, so leaving the screen or backgrounding the
    /// app cancels the loop automatically.
    func runAutomaticRefresh(every interval: Duration = .seconds(30)) async {
        loadIfNeeded()
        await refreshDepartures()

        while !Task.isCancelled {
            do {
                try await Task.sleep(for: interval)
            } catch {
                return
            }

            guard !Task.isCancelled else { return }
            await refreshDepartures()
        }
    }

    private func requestLocation() {
        loadTask?.cancel()

        locationModel.requestLocation()
    }

    private func handle(_ locationState: LocationState) {
        switch locationState {
        case .idle(let authorization):
            switch authorization {
            case .authorized:
                state = .locating
                locationModel.requestLocation()
            case .notDetermined:
                state = .locating
            case .restricted, .denied:
                state = .locationUnavailable(authorization)
            }
        case .locating:
            state = .locating
        case .located(let coordinate):
            loadStations(near: coordinate)
        case .failed(let authorization):
            state = .locationUnavailable(authorization)
        }
    }

    private func loadStations(near coordinate: GeoCoordinate) {
        loadTask?.cancel()
        refreshGeneration &+= 1
        let generation = refreshGeneration
        stationCandidate = nil

        let previous = lastOverview
        state = .loading(previous: previous)

        let networkRepository = self.networkRepository
        let departuresRepository = self.departuresRepository
        let requestedAt = now()
        let bounds = Self.searchBounds(around: coordinate)

        loadTask = Task { [weak self] in
            do {
                let area = try await networkRepository.viewport(in: bounds)
                try Task.checkCancellation()

                guard let self, self.refreshGeneration == generation else { return }

                guard let candidate = StationOverviewBuilder.nearestStation(
                    in: area,
                    to: coordinate
                ) else {
                    self.state = .empty
                    return
                }

                self.stationCandidate = candidate

                let board: DepartureBoard
                do {
                    board = try await departuresRepository.board(stationID: candidate.station.id)
                } catch is CancellationError {
                    throw CancellationError()
                } catch {
                    board = DepartureBoard(
                        source: .unavailable,
                        generatedAt: requestedAt,
                        groups: []
                    )
                }

                try Task.checkCancellation()
                guard self.refreshGeneration == generation else { return }

                let overviewNow = self.now()
                let overview = StationOverviewBuilder.makeOverview(
                    from: candidate,
                    board: board,
                    now: overviewNow
                )
                self.lastOverview = overview
                self.state = .loaded(overview)
            } catch is CancellationError {
            } catch {
                guard let self, self.refreshGeneration == generation else { return }
                self.state = .failed(error.via, previous: previous)
            }
        }
    }

    private func refreshDepartures() async {
        guard let candidate = stationCandidate else { return }

        let generation = refreshGeneration
        let previous = lastOverview

        do {
            let board = try await departuresRepository.board(stationID: candidate.station.id)
            try Task.checkCancellation()
            guard refreshGeneration == generation,
                  stationCandidate?.station.id == candidate.station.id else { return }

            let overview = StationOverviewBuilder.makeOverview(
                from: candidate,
                board: board,
                now: now()
            )
            lastOverview = overview
            state = .loaded(overview)
        } catch is CancellationError {
        } catch {
            guard refreshGeneration == generation,
                  stationCandidate?.station.id == candidate.station.id else { return }
            state = .failed(error.via, previous: previous)
        }
    }

    static func searchBounds(
        around coordinate: GeoCoordinate,
        radiusMeters: Double = 2_000
    ) -> GeoBounds {
        let latitudeDelta = radiusMeters / 111_000
        let longitudeMetersPerDegree = max(
            1_000,
            111_000 * abs(cos(coordinate.latitude * .pi / 180))
        )
        let longitudeDelta = radiusMeters / longitudeMetersPerDegree

        return GeoBounds(
            minLatitude: max(-90, coordinate.latitude - latitudeDelta),
            maxLatitude: min(90, coordinate.latitude + latitudeDelta),
            minLongitude: max(-180, coordinate.longitude - longitudeDelta),
            maxLongitude: min(180, coordinate.longitude + longitudeDelta)
        )
    }
}
