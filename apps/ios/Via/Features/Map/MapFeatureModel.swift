import CoreLocation
import Foundation
import Observation

@MainActor
@Observable
final class MapFeatureModel {
    static let paris = GeoCoordinate(latitude: 48.8566, longitude: 2.3522)

    let transitAPI: any TransitAPI
    let locationProvider: any LocationProviding
    let recentSearchStore: any RecentSearchStore
    let clock: any ViaClock
    let networkModel: TransitNetworkModel
    let naturalJourneyModel: NaturalJourneyModel
    let searchModel: SearchModel
    let departuresModel: DeparturesModel
    let journeyModel: JourneyModel

    var flow = MapFlowState()
    var recentSearches: [SearchResult]
    var locationState: LocationState = .notDetermined
    var cameraTarget: GeoCoordinate?

    private var selectedStationOverride: NetworkStation?
    private var loadedTiles: [String: StationsInArea] = [:]
    private var inFlightTiles = Set<String>()
    private var didStart = false
    private var viewportTask: Task<Void, Never>?
    private var pendingStationID: String?

    init(
        transitAPI: any TransitAPI,
        locationProvider: any LocationProviding,
        recentSearchStore: any RecentSearchStore = UserDefaultsRecentSearchStore(),
        clock: any ViaClock = SystemViaClock(),
        networkModel: TransitNetworkModel? = nil
    ) {
        self.transitAPI = transitAPI
        self.locationProvider = locationProvider
        self.recentSearchStore = recentSearchStore
        self.clock = clock
        let sharedNetworkModel = networkModel ?? TransitNetworkModel(transitAPI: transitAPI)
        self.networkModel = sharedNetworkModel
        self.naturalJourneyModel = NaturalJourneyModel(transitAPI: transitAPI)
        self.searchModel = SearchModel(
            transitAPI: transitAPI,
            locationProvider: locationProvider,
            clock: clock
        )
        self.departuresModel = DeparturesModel(transitAPI: transitAPI, clock: clock)
        self.journeyModel = JourneyModel(transitAPI: transitAPI)
        recentSearches = recentSearchStore.load()
        locationProvider.onUpdate = { [weak self] update in
            self?.handleLocationUpdate(update)
        }
        sharedNetworkModel.onReady = { [weak self] in
            self?.resolvePendingStation()
        }
        naturalJourneyModel.onStateChange = { [weak self] state in
            self?.handleNaturalJourneyStateChange(state)
        }
        journeyModel.onStateChange = { [weak self] state in
            self?.handleJourneyStateChange(state)
        }
    }

    var selectedStation: NetworkStation? {
        if let selectedStationOverride { return selectedStationOverride }
        guard let id = flow.selectedStationID else { return nil }
        return mapStations.first(where: { $0.id == id })
    }

    var selectedJourney: Journey? {
        guard let response = journeyModel.state.response,
              let index = flow.selectedJourneyIndex,
              response.journeys.indices.contains(index)
        else { return nil }
        return response.journeys[index]
    }

    var mapStations: [NetworkStation] {
        var byID = Dictionary(uniqueKeysWithValues: networkModel.stations.map { ($0.id, $0) })
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

    private var currentLocationCoordinate: GeoCoordinate? {
        if case .ready(let coordinate) = locationState {
            return coordinate
        }
        return nil
    }

    func distanceMeters(to coordinate: GeoCoordinate) -> Double {
        coordinate.distance(to: currentCoordinate)
    }

    func start() {
        guard !didStart else { return }
        didStart = true

        refreshLocationState()
        if locationProvider.authorization == .authorized {
            locationProvider.startUpdatingLocation()
        }

        loadNetwork()
    }

    func requestLocationPermission() {
        switch locationProvider.authorization {
        case .notDetermined:
            locationState = .loading
            locationProvider.requestWhenInUseAuthorization()
        case .authorized:
            locationProvider.startUpdatingLocation()
            refreshLocationState()
        case .denied, .restricted:
            locationState = .denied
        }
    }

    func continueWithoutLocation() {
        locationState = .manual
    }

    func loadNetwork() {
        networkModel.loadNetwork()
    }

    func setSearchFocused(_ focused: Bool) {
        flow = transitionMapFlow(flow, event: .searchFocusChanged(focused))
    }

    func changeSheetDetent(by translation: CGFloat) {
        guard abs(translation) >= 40 else { return }
        let nextIndex = min(
            2,
            max(0, flow.overviewDetentIndex + (translation < 0 ? 1 : -1))
        )
        flow = transitionMapFlow(flow, event: .detentChanged(nextIndex))
    }

    func setSearchQuery(_ query: String) {
        searchModel.setQuery(query)
        flow = transitionMapFlow(
            flow,
            event: .queryChanged(
                hasText: !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            )
        )
    }

    func retrySearch() {
        searchModel.retry()
    }

    func selectSearchResult(_ result: SearchResult) {
        rememberRecentSearch(result)
        switch result {
        case .station(let stationResult):
            let station = NetworkStation(
                id: stationResult.id,
                name: stationResult.name,
                coordinate: stationResult.coordinate,
                routeIds: stationResult.routes.map(\.id)
            )
            selectStation(station)
        case .address:
            guard let destination = JourneyDestination(searchResult: result) else { return }
            planJourney(to: destination)
        }
    }

    func removeRecentSearch(_ result: SearchResult) {
        let key = recentSearchKey(result)
        recentSearches.removeAll { recentSearchKey($0) == key }
        recentSearchStore.save(recentSearches)
    }

    func clearRecentSearches() {
        recentSearches = []
        recentSearchStore.save([])
    }

    func selectStation(_ station: NetworkStation) {
        naturalJourneyModel.cancel()
        journeyModel.cancel()
        selectedStationOverride = station
        flow = transitionMapFlow(
            flow,
            event: .stationSelected(id: station.id)
        )
        cameraTarget = station.coordinate
        ensureArea(around: station.coordinate)
        departuresModel.start(for: station.id)
    }

    func openStation(id: String) {
        guard !id.isEmpty else { return }

        if let station = mapStations.first(where: { $0.id == id }) {
            selectStation(station)
        } else {
            pendingStationID = id
            start()
            networkModel.loadNetwork()
        }
    }

    func closeSelectedStation() {
        naturalJourneyModel.cancel()
        departuresModel.reset()
        journeyModel.cancel()
        selectedStationOverride = nil
        flow = transitionMapFlow(flow, event: .stationDeselected)
    }

    func planSelectedStation() {
        guard let station = selectedStation else { return }

        planJourney(to: JourneyDestination(station: station))
    }

    private func planJourney(to destination: JourneyDestination) {
        naturalJourneyModel.cancel()
        journeyModel.plan(to: destination, from: currentCoordinate)
    }

    func submitNaturalJourney(_ query: String) {
        journeyModel.cancel()
        naturalJourneyModel.submit(query, currentLocation: currentLocationCoordinate)
    }

    func resolveNaturalJourney(_ choice: NaturalJourneyChoice) {
        guard naturalJourneyModel.resolve(choice, currentLocation: currentLocationCoordinate) else { return }
        journeyModel.cancel()
    }

    func retryNaturalJourney() {
        guard naturalJourneyModel.retry() else { return }
        journeyModel.cancel()
    }

    func cancelNaturalJourney() {
        naturalJourneyModel.cancel()
        journeyModel.cancel()
        flow = transitionMapFlow(flow, event: .naturalJourneyCancelled)
    }

    func selectJourney(at index: Int) {
        guard let response = journeyModel.state.response, response.journeys.indices.contains(index) else { return }
        flow = transitionMapFlow(flow, event: .journeyDetailOpened(index: index))
    }

    func closeJourneyDetail() {
        flow = transitionMapFlow(flow, event: .journeyDetailClosed)
    }

    func cancelJourney() {
        journeyModel.cancel()
        flow = transitionMapFlow(flow, event: .journeyCancelled)
    }

    func retryJourney() {
        if !journeyModel.retry() {
            planSelectedStation()
        }
    }

    func reportViewport(_ region: ViewportRegion) {
        guard region.longitudeDelta <= 0.024 else { return }
        viewportTask?.cancel()
        viewportTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await self.clock.sleep(for: .milliseconds(250))
                guard !Task.isCancelled else { return }
                await self.loadTiles(keys: ViewportTiles.keys(for: region))
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
            refreshLocationState()
            if let stationID = flow.selectedStationID {
                departuresModel.start(for: stationID)
            }
        } else {
            departuresModel.stopPolling()
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

    private func handleNaturalJourneyStateChange(_ state: NaturalJourneyState) {
        switch state {
        case .idle:
            break
        case .interpreting:
            journeyModel.cancel()
            flow = transitionMapFlow(flow, event: .naturalJourneySubmitted)
        case .needsClarification:
            flow = transitionMapFlow(flow, event: .naturalJourneyNeedsClarification)
        case .ready(let ready):
            rememberRecentSearch(ready.interpretation.destinationResult)
            let request = JourneyRequest(
                origin: currentCoordinate,
                destination: ready.interpretation.destination
            )
            journeyModel.adopt(request: request, response: ready.journeys)
        case .failed:
            flow = transitionMapFlow(flow, event: .naturalJourneyFailed)
        }
    }

    private func handleJourneyStateChange(_ state: JourneyState) {
        switch state {
        case .idle:
            break
        case .planning:
            flow = transitionMapFlow(flow, event: .journeyPlanningStarted)
        case .ready, .failed:
            if naturalJourneyModel.state.isActive {
                flow = transitionMapFlow(flow, event: .naturalJourneyReady)
            } else {
                flow = transitionMapFlow(flow, event: .journeyResultsReady)
            }
        }
    }

    private func rememberRecentSearch(_ result: SearchResult) {
        recentSearches = rememberRecentSearches(recentSearches, result: result)
        recentSearchStore.save(recentSearches)
    }

    private func refreshLocationState() {
        if case .manual = locationState,
           locationProvider.authorization == .notDetermined {
            return
        }

        locationState = makeLocationState(
            for: locationProvider.authorization,
            coordinate: locationProvider.coordinate
        )
    }

    private func handleLocationUpdate(_ update: LocationUpdate) {
        switch update {
        case .authorizationChanged:
            refreshLocationState()
        case .coordinateUpdated(let coordinate):
            locationState = .ready(coordinate)
        }
    }

    private func resolvePendingStation() {
        guard let pendingStationID,
              let station = mapStations.first(where: { $0.id == pendingStationID })
        else { return }

        self.pendingStationID = nil
        selectStation(station)
    }

}
