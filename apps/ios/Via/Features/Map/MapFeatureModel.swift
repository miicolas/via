import CoreLocation
import Foundation
import Observation

enum NetworkState: Equatable, Sendable {
    case loading
    case ready
    case failed
}

enum SearchState: Equatable, Sendable {
    case idle
    case loading(previous: [SearchResult])
    case ready(results: [SearchResult], banUnavailable: Bool)
    case failed(previous: [SearchResult])

    var results: [SearchResult] {
        switch self {
        case .idle: []
        case .loading(let previous), .failed(let previous): previous
        case .ready(let results, _): results
        }
    }
}

enum DeparturesState: Equatable, Sendable {
    case idle
    case loading
    case ready(response: DeparturesResponse, stale: Bool)
    case failed

    var response: DeparturesResponse? {
        if case .ready(let response, _) = self { return response }
        return nil
    }
}

@MainActor
@Observable
final class MapFeatureModel {
    static let paris = GeoCoordinate(latitude: 48.8566, longitude: 2.3522)

    let transitAPI: any TransitAPI
    let locationProvider: any LocationProviding

    var flow = MapFlowState()
    var railMap: RailMap?
    var networkState: NetworkState = .loading
    var searchState: SearchState = .idle
    var departuresState: DeparturesState = .idle
    var journeyState: JourneyState = .idle
    var locationState: LocationState = .loading
    var cameraTarget: GeoCoordinate?
    var searchQuery = ""

    private var selectedStationOverride: NetworkStation?
    private var loadedTiles: [String: StationsInArea] = [:]
    private var inFlightTiles = Set<String>()
    private var didStart = false
    private var networkTask: Task<Void, Never>?
    private var searchTask: Task<Void, Never>?
    private var viewportTask: Task<Void, Never>?
    private var departureTask: Task<Void, Never>?
    private var journeyTask: Task<Void, Never>?

    init(transitAPI: any TransitAPI, locationProvider: any LocationProviding) {
        self.transitAPI = transitAPI
        self.locationProvider = locationProvider
    }

    var selectedStation: NetworkStation? {
        if let selectedStationOverride { return selectedStationOverride }
        guard let id = flow.selectedStationID else { return nil }
        return mapStations.first(where: { $0.id == id })
    }

    var selectedJourney: Journey? {
        guard let response = journeyState.response,
              let index = flow.selectedJourneyIndex,
              response.journeys.indices.contains(index)
        else { return nil }
        return response.journeys[index]
    }

    var mapStations: [NetworkStation] {
        var byID = Dictionary(uniqueKeysWithValues: railMap?.stations.map { ($0.id, $0) } ?? [])
        for station in loadedTiles.values.flatMap(\.stations) {
            guard let existing = byID[station.id] else {
                byID[station.id] = station
                continue
            }

            let routeIDs = existing.routeIds + station.routeIds.filter { !existing.routeIds.contains($0) }
            byID[station.id] = NetworkStation(
                id: existing.id,
                name: existing.name,
                coordinate: existing.coordinate,
                routeIds: routeIDs
            )
        }
        return Array(byID.values)
    }

    var mapRoutes: [NetworkRoute] {
        railMap?.routes.sortedForDisplay ?? []
    }

    var nearbyStations: [NetworkStation] {
        let origin = currentCoordinate
        return mapStations
            .sorted { $0.coordinate.distance(to: origin) < $1.coordinate.distance(to: origin) }
            .prefix(8)
            .map { $0 }
    }

    var currentCoordinate: GeoCoordinate {
        if case .ready(let coordinate) = locationState {
            return coordinate
        }
        return Self.paris
    }

    func distanceMeters(to coordinate: GeoCoordinate) -> Double {
        coordinate.distance(to: currentCoordinate)
    }

    func start() {
        guard !didStart else { return }
        didStart = true

        locationProvider.requestWhenInUseAuthorization()
        if let coordinate = locationProvider.coordinate {
            locationState = .ready(coordinate)
        } else if locationProvider.authorizationStatus == .denied ||
                    locationProvider.authorizationStatus == .restricted {
            locationState = .denied
        } else {
            locationState = .ready(Self.paris)
        }

        loadNetwork()
    }

    func loadNetwork() {
        networkTask?.cancel()
        networkState = .loading
        networkTask = Task { [weak self] in
            guard let self else { return }
            do {
                let network = try await transitAPI.loadRailMap()
                guard !Task.isCancelled else { return }
                railMap = network
                networkState = network.routes.isEmpty ? .failed : .ready
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                networkState = .failed
            }
        }
    }

    func setSearchFocused(_ focused: Bool) {
        flow = transitionMapFlow(flow, event: .searchFocusChanged(focused))
    }

    func setSearchQuery(_ query: String) {
        searchQuery = query
        flow = transitionMapFlow(flow, event: .queryChanged(query))
        searchTask?.cancel()

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            searchState = .idle
            return
        }

        let previous = searchState.results
        searchState = .loading(previous: previous)
        searchTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: 600_000_000)
                guard let self, !Task.isCancelled else { return }
                let response = try await transitAPI.search(query: trimmed, near: locationProvider.coordinate)
                guard !Task.isCancelled, searchQuery.trimmingCharacters(in: .whitespacesAndNewlines) == trimmed else {
                    return
                }
                searchState = .ready(
                    results: response.results,
                    banUnavailable: response.sources.ban == .unavailable
                )
            } catch is CancellationError {
                return
            } catch {
                guard let self, !Task.isCancelled else { return }
                self.searchState = .failed(previous: previous)
            }
        }
    }

    func selectSearchResult(_ result: SearchResult) {
        guard case .station(let stationResult) = result else { return }
        let station = NetworkStation(
            id: stationResult.id,
            name: stationResult.name,
            coordinate: stationResult.coordinate,
            routeIds: stationResult.routes.map(\.id)
        )
        selectStation(station)
    }

    func selectStation(_ station: NetworkStation) {
        journeyTask?.cancel()
        journeyTask = nil
        journeyState = .idle
        selectedStationOverride = station
        flow = transitionMapFlow(
            flow,
            event: .stationSelected(id: station.id, query: searchQuery)
        )
        cameraTarget = station.coordinate
        ensureArea(around: station.coordinate)
        startDeparturePolling()
    }

    func closeSelectedStation() {
        departureTask?.cancel()
        departureTask = nil
        journeyTask?.cancel()
        journeyTask = nil
        departuresState = .idle
        journeyState = .idle
        selectedStationOverride = nil
        flow = transitionMapFlow(flow, event: .stationDeselected)
    }

    func planSelectedStation() {
        guard let station = selectedStation else { return }

        let request = JourneyRequest(
            origin: currentCoordinate,
            destination: JourneyDestination(station: station)
        )
        journeyTask?.cancel()
        journeyState = .planning(request: request)
        flow = transitionMapFlow(flow, event: .journeyPlanningStarted)
        journeyTask = Task { [weak self] in
            guard let self else { return }
            do {
                let response = try await transitAPI.planJourneys(request)
                guard !Task.isCancelled, journeyState.request?.key == request.key else { return }
                journeyState = .ready(request: request, response: response)
                flow = transitionMapFlow(flow, event: .journeyResultsReady)
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled, journeyState.request?.key == request.key else { return }
                journeyState = .failed(request: request)
                flow = transitionMapFlow(flow, event: .journeyResultsReady)
            }
        }
    }

    func selectJourney(at index: Int) {
        guard let response = journeyState.response, response.journeys.indices.contains(index) else { return }
        flow = transitionMapFlow(flow, event: .journeyDetailOpened(index: index))
    }

    func closeJourneyDetail() {
        flow = transitionMapFlow(flow, event: .journeyDetailClosed)
    }

    func cancelJourney() {
        journeyTask?.cancel()
        journeyTask = nil
        journeyState = .idle
        flow = transitionMapFlow(flow, event: .journeyCancelled)
    }

    func retryJourney() {
        planSelectedStation()
    }

    func reportViewport(_ region: ViewportRegion) {
        guard region.longitudeDelta <= 0.024 else { return }
        viewportTask?.cancel()
        viewportTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: 250_000_000)
                guard let self, !Task.isCancelled else { return }
                await loadTiles(keys: ViewportTiles.keys(for: region))
            } catch is CancellationError {
                return
            } catch {
                return
            }
        }
    }

    func ensureArea(around coordinate: GeoCoordinate) {
        let region = ViewportRegion(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            latitudeDelta: ViewportTiles.tileSizeDegrees,
            longitudeDelta: ViewportTiles.tileSizeDegrees
        )
        let keys = ViewportTiles.keys(for: region)
        viewportTask?.cancel()
        viewportTask = Task { [weak self] in
            guard let self else { return }
            await loadTiles(keys: keys)
        }
    }

    func handle(isActive: Bool) {
        if isActive {
            if flow.selectedStationID != nil { startDeparturePolling() }
        } else {
            departureTask?.cancel()
            departureTask = nil
        }
    }

    private func loadTiles(keys: [String]) async {
        for key in keys where !Task.isCancelled {
            guard !loadedTiles.keys.contains(key), !inFlightTiles.contains(key),
                  let bounds = ViewportTiles.bounds(for: key)
            else { continue }

            inFlightTiles.insert(key)
            defer { inFlightTiles.remove(key) }

            do {
                loadedTiles[key] = try await transitAPI.loadStations(in: bounds)
            } catch is CancellationError {
                return
            } catch {
                continue
            }
        }
    }

    private func startDeparturePolling() {
        departureTask?.cancel()
        departureTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                guard let stationID = flow.selectedStationID else { return }
                if departuresState.response == nil { departuresState = .loading }

                do {
                    let response = try await transitAPI.loadDepartures(stationID: stationID)
                    guard !Task.isCancelled, flow.selectedStationID == stationID else { return }
                    departuresState = .ready(response: response, stale: false)
                } catch is CancellationError {
                    return
                } catch {
                    if let response = departuresState.response {
                        departuresState = .ready(response: response, stale: true)
                    } else {
                        departuresState = .failed
                    }
                }

                do {
                    try await Task.sleep(nanoseconds: 60_000_000_000)
                } catch {
                    return
                }
            }
        }
    }
}
