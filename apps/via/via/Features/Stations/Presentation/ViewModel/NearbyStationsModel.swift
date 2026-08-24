import Foundation
import OSLog
import Observation

struct NearbyStation: Identifiable, Sendable, Hashable {
    let item: StationMapItem
    let distanceMeters: Double

    var id: StationID { item.id }
}

enum NearbyStationsLoadingState: Sendable, Equatable {
    case idle
    case loading
    case loaded
    case failed(ViaError)
}

/// What matches the filter around the point the traveller is looking at.
///
/// The map only draws stations below `NetworkViewport.showsStations` — beyond
/// it there are thousands of them and no bounded request that could fetch them.
/// A *filtered* set has no such problem: it is capped by a radius and a count
/// before it is asked for, so it can be listed at any zoom. The map only draws
/// it when this circle covers the whole viewport and the filtered result is
/// complete; otherwise a partial set would advertise its loading boundary.
/// Both the annotations and Stations list read this model rather than each
/// running their own query and disagreeing.
///
/// The anchor is the map's centre, not the traveller's position: it works with
/// no location permission, and it follows what is on screen. It decides the
/// *order* and where the radius is measured from — never who is in the set,
/// which is the filter's job alone.
@MainActor
@Observable
final class NearbyStationsModel {
    /// Under `STATIONS_AREA_MAX_SPAN_DEGREES` (0.05°) once doubled, so one
    /// request covers the whole box, and at most four viewport tiles.
    static let radiusMeters = 2_000.0
    /// The list is a walk away, not an inventory: past this the ranking is
    /// noise. The count is shown, so nothing is silently dropped.
    static let resultLimit = 50
    /// A pan of a few metres must not reorder rows under a scrolling thumb.
    static let minimumAnchorShiftMeters = 250.0

    private(set) var results: [NearbyStation] = []
    private(set) var loading: NearbyStationsLoadingState = .idle
    private(set) var anchor: GeoCoordinate?
    /// Every station in the radius, filter aside. `results.isEmpty` alone
    /// cannot tell "the filter hides everything here" from "there is nothing
    /// here", and those are two different things to say.
    private(set) var matchesBeforeFilter = 0
    /// Count after filtering but before the list limit. If this exceeds the
    /// limit, the map hides the set instead of exposing a visible cutoff.
    private(set) var matchingResultCount = 0
    private(set) var bikeSourceAvailable = true

    var filter: StationMapFilter { filterStore.filter }

    /// Fired when `results` change for any reason. The map republishes its
    /// snapshot from it and the Stations tab reloads its hero board; views
    /// observe `results` directly. Nothing unregisters — both consumers live
    /// as long as this does, and each captures itself weakly.
    @ObservationIgnored private var resultObservers: [@MainActor () -> Void] = []

    @ObservationIgnored private let repository: any NetworkRepository
    @ObservationIgnored private let filterStore: StationMapFilterStore
    @ObservationIgnored private var loadedStations: [StationMapItem] = []
    @ObservationIgnored private var loadedBikeStations: [StationMapItem] = []
    /// Distinguishes "never asked for docks" from "asked, and there are none
    /// here" — without it an area with no docks refetches on every filter tap.
    @ObservationIgnored private var hasLoadedBikeStations = false
    @ObservationIgnored private var loadedAnchor: GeoCoordinate?
    @ObservationIgnored private var loadTask: Task<Void, Never>?
    @ObservationIgnored private var generation = 0

    init(repository: any NetworkRepository, filterStore: StationMapFilterStore) {
        self.repository = repository
        self.filterStore = filterStore
        filterStore.onChange { [weak self] _ in
            self?.filterChanged()
        }
    }

    /// The camera settled somewhere new. A short hop re-sorts what is already
    /// held; a real move refetches.
    func anchorChanged(to coordinate: GeoCoordinate) {
        anchor = coordinate

        guard let loadedAnchor else {
            load()
            return
        }
        if coordinate.metersAway(from: loadedAnchor) < Self.minimumAnchorShiftMeters {
            publish()
            return
        }
        load()
    }

    func retry() {
        load()
    }

    func onResultsChange(_ body: @escaping @MainActor () -> Void) {
        resultObservers.append(body)
    }

    /// A `NetworkStation` again, so a nearby row can feed the same overview
    /// builder the Stations tab already uses for its departure board.
    static func candidate(for station: NearbyStation) -> StationCandidate {
        StationCandidate(
            station: NetworkStation(
                id: station.item.id,
                name: station.item.name,
                coordinate: station.item.coordinate,
                routeIDs: station.item.routes.map(\.id),
                accessibility: station.item.accessibility,
                hasElevators: station.item.hasElevators,
                toilets: station.item.toilets
            ),
            routes: station.item.routes,
            distanceMeters: station.distanceMeters
        )
    }

    /// The map only draws a complete nearby result. Returning a nearest-only
    /// prefix creates a conspicuous circle surrounded by apparently empty map.
    var annotationItems: [StationMapItem] {
        guard matchingResultCount <= Self.resultLimit else { return [] }
        return results.map(\.item)
    }

    /// The box the results occupy, for a camera that only ever tightens.
    var resultsBounds: GeoBounds? {
        guard let first = results.first else { return nil }
        var minLatitude = first.item.coordinate.latitude
        var maxLatitude = minLatitude
        var minLongitude = first.item.coordinate.longitude
        var maxLongitude = minLongitude

        for station in results.dropFirst() {
            let coordinate = station.item.coordinate
            minLatitude = min(minLatitude, coordinate.latitude)
            maxLatitude = max(maxLatitude, coordinate.latitude)
            minLongitude = min(minLongitude, coordinate.longitude)
            maxLongitude = max(maxLongitude, coordinate.longitude)
        }

        return GeoBounds(
            minLatitude: minLatitude,
            maxLatitude: maxLatitude,
            minLongitude: minLongitude,
            maxLongitude: maxLongitude
        )
    }

    /// Docks carry no departure board, so the hero row skips them.
    var heroStation: NearbyStation? {
        results.first { $0.item.bikeStation == nil }
    }

    private func filterChanged() {
        // Turning the dock layer on is a request for counts the last fetch had
        // no reason to make; everything else re-filters what is already held.
        if filterStore.filter.contains(.bikeStations), !hasLoadedBikeStations {
            load()
        } else {
            publish()
        }
    }

    private func load() {
        guard let anchor else { return }

        loadTask?.cancel()
        generation &+= 1
        let generation = self.generation
        loading = .loading

        hasLoadedBikeStations = false
        let bounds = GeoBounds.around(anchor, radiusMeters: Self.radiusMeters)
        let repository = self.repository
        let wantsBikeStations = filterStore.filter.contains(.bikeStations)

        loadTask = Task { [weak self] in
            do {
                async let area = repository.viewport(in: bounds)
                async let bikeArea: BikeStationsArea? =
                    wantsBikeStations ? try await repository.bikeStations(in: bounds) : nil

                let (fetchedStations, fetchedBikes) = try await (area, bikeArea)
                try Task.checkCancellation()

                guard let self, self.generation == generation else { return }
                self.loadedStations = fetchedStations.transitMapItems
                self.loadedBikeStations = fetchedBikes?.mapItems ?? []
                self.hasLoadedBikeStations = fetchedBikes != nil
                self.bikeSourceAvailable = fetchedBikes?.sourceAvailable ?? true
                self.loadedAnchor = anchor
                self.loading = .loaded
                self.publish()
            } catch is CancellationError {
            } catch {
                guard let self, self.generation == generation else { return }
                self.loading = .failed(error.via)
                AppLog.network.error(
                    "Nearby stations failed: \(String(describing: error), privacy: .private(mask: .hash))"
                )
            }
        }
    }

    private func publish() {
        guard let anchor else { return }
        let filter = filterStore.filter

        var candidates = loadedStations
        if filter.contains(.bikeStations) {
            candidates += loadedBikeStations
        }

        let withinRadius = candidates.compactMap { item -> NearbyStation? in
            let distance = item.coordinate.metersAway(from: anchor)
            guard distance <= Self.radiusMeters else { return nil }
            return NearbyStation(item: item, distanceMeters: distance)
        }

        let previousMatchingResultCount = matchingResultCount
        matchesBeforeFilter = withinRadius.count
        let matching = withinRadius
            .filter { filter.matches($0.item) }
            .sorted { $0.distanceMeters < $1.distanceMeters }
        matchingResultCount = matching.count

        let updated = Array(matching.prefix(Self.resultLimit))
        guard updated != results || matchingResultCount != previousMatchingResultCount else {
            return
        }
        results = updated
        for observer in resultObservers { observer() }
    }
}
