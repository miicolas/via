import CoreLocation
import Foundation
import Observation

/// Feeds the home sheet's "À proximité" section: the closest stations around
/// the user, each with its own polling departures board. Falls back to the
/// favorite stations when location is unavailable.
@MainActor
@Observable
final class NearbyStationsViewModel {
    struct Entry: Identifiable {
        let station: StationMapItem
        let departures: DeparturesViewModel

        var id: StationID { station.id }
    }

    private(set) var entries: [Entry] = []
    private(set) var isLoading = false
    private(set) var isUsingFavoritesFallback = false

    @ObservationIgnored private let network: any NetworkRepository
    @ObservationIgnored private let makeDeparturesViewModel: (StationID) -> DeparturesViewModel
    @ObservationIgnored private var loadTask: Task<Void, Never>?
    @ObservationIgnored private var loadedAnchor: GeoCoordinate?
    @ObservationIgnored private var isStarted = false
    @ObservationIgnored private var isSceneActive = true

    /// Half-size of the viewport queried around the anchor, in degrees
    /// (~650 m); well under the API's bbox cap.
    private static let radiusDegrees = 0.006
    private static let stationCount = 2
    /// Distance the anchor must move before stations are recomputed.
    private static let minimumMoveMeters: Double = 150

    init(
        network: any NetworkRepository,
        makeDeparturesViewModel: @escaping (StationID) -> DeparturesViewModel
    ) {
        self.network = network
        self.makeDeparturesViewModel = makeDeparturesViewModel
    }

    func start() {
        isStarted = true
        for entry in entries {
            entry.departures.start()
            entry.departures.setSceneActive(isSceneActive)
        }
    }

    func stop() {
        isStarted = false
        for entry in entries { entry.departures.stop() }
    }

    func setSceneActive(_ active: Bool) {
        isSceneActive = active
        for entry in entries { entry.departures.setSceneActive(active) }
    }

    func update(location: LocationState, favorites: [FavoriteStation]) {
        switch location {
        case .located(let coordinate):
            guard shouldReload(around: coordinate) else { return }
            load(around: coordinate)
        case .failed:
            loadTask?.cancel()
            loadTask = nil
            loadedAnchor = nil
            isLoading = false
            applyFavoritesFallback(favorites)
        case .idle, .locating:
            break
        }
    }

    private func shouldReload(around coordinate: GeoCoordinate) -> Bool {
        if isUsingFavoritesFallback { return true }
        guard let loadedAnchor else { return true }
        return loadedAnchor.metersAway(from: coordinate) > Self.minimumMoveMeters
    }

    private func load(around coordinate: GeoCoordinate) {
        loadTask?.cancel()
        loadedAnchor = coordinate
        isLoading = entries.isEmpty
        let bounds = GeoBounds(
            minLatitude: coordinate.latitude - Self.radiusDegrees,
            maxLatitude: coordinate.latitude + Self.radiusDegrees,
            minLongitude: coordinate.longitude - Self.radiusDegrees,
            maxLongitude: coordinate.longitude + Self.radiusDegrees
        )
        loadTask = Task { [weak self, network] in
            // On failure, keep whatever was on screen; the section hides when empty.
            let area = try? await network.viewport(in: bounds)
            guard let self, !Task.isCancelled else { return }
            isLoading = false
            guard let area else { return }
            isUsingFavoritesFallback = false
            present(Self.closestStations(in: area, to: coordinate))
        }
    }

    private func applyFavoritesFallback(_ favorites: [FavoriteStation]) {
        let stations = favorites
            .compactMap { favorite -> StationMapItem? in
                guard let coordinate = favorite.coordinate else { return nil }
                return StationMapItem(
                    id: StationID(rawValue: favorite.stationID),
                    name: favorite.name,
                    coordinate: coordinate,
                    routes: []
                )
            }
            .prefix(Self.stationCount)
        isUsingFavoritesFallback = true
        present(Array(stations))
    }

    /// The closest stations, rail first so the section leads with train
    /// departures, topped up with bus stops when rail is scarce. Distances are
    /// computed once per station, not per sort comparison.
    private static func closestStations(
        in area: StationsArea,
        to anchor: GeoCoordinate
    ) -> [StationMapItem] {
        area.mapItems
            .map { station in
                (station: station,
                 busOnly: !station.modes.contains { $0 != .bus },
                 distance: station.coordinate.metersAway(from: anchor))
            }
            .sorted { ($0.busOnly ? 1 : 0, $0.distance) < ($1.busOnly ? 1 : 0, $1.distance) }
            .prefix(stationCount)
            .map(\.station)
    }

    private func present(_ stations: [StationMapItem]) {
        let previous = entries
        entries = stations.map { station in
            if let existing = previous.first(where: { $0.station.id == station.id }) {
                return Entry(station: station, departures: existing.departures)
            }
            let departures = makeDeparturesViewModel(station.id)
            if isStarted {
                departures.start()
                departures.setSceneActive(isSceneActive)
            }
            return Entry(station: station, departures: departures)
        }
        let kept = Set(entries.map(\.id))
        for entry in previous where !kept.contains(entry.id) {
            entry.departures.stop()
        }
    }
}
