import Foundation
import Observation

enum ReportStationSelectionSource: Sendable, Hashable {
    case automatic
    case manual
}

struct ReportStationSelection: Sendable, Hashable {
    let station: ReportStation
    let coordinate: GeoCoordinate
    let source: ReportStationSelectionSource

    func context(activeJourney: ActiveJourneyContext? = nil) -> ReportContext {
        ReportContext(
            coordinate: coordinate,
            station: station,
            lineID: activeJourney?.lineID,
            journeyID: activeJourney?.journeyID,
            vehicleID: activeJourney?.vehicleID
        )
    }
}

enum ReportContextResolutionState: Sendable, Equatable {
    case idle
    case loading
    case resolved(ReportStationSelection)
    case unavailable(LocationAuthorization)
    case empty
    case error(ViaError)

    var selection: ReportStationSelection? {
        guard case .resolved(let selection) = self else { return nil }
        return selection
    }
}

@MainActor
@Observable
final class ReportContextResolver {
    private(set) var state: ReportContextResolutionState = .idle

    @ObservationIgnored private let locationModel: LocationModel
    @ObservationIgnored private let networkRepository: any NetworkRepository
    @ObservationIgnored private var resolutionTask: Task<Void, Never>?
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var hasStarted = false

    init(
        locationModel: LocationModel,
        networkRepository: any NetworkRepository
    ) {
        self.locationModel = locationModel
        self.networkRepository = networkRepository
    }

    func loadIfNeeded() {
        guard !hasStarted else { return }
        hasStarted = true
        resolve()
    }

    func retry() {
        hasStarted = true
        resolve()
    }

    func selectManualStation(_ station: StationSearchResult) {
        resolutionTask?.cancel()
        generation &+= 1

        state = .resolved(ReportStationSelection(
            station: ReportStation(searchResult: station),
            coordinate: locationModel.coordinate ?? station.coordinate,
            source: .manual
        ))
    }

    private func resolve() {
        resolutionTask?.cancel()
        generation &+= 1
        let requestedGeneration = generation
        state = .loading

        let locationModel = self.locationModel
        let networkRepository = self.networkRepository

        resolutionTask = Task { [weak self] in
            guard let coordinate = await locationModel.requestCurrentLocation() else {
                guard !Task.isCancelled,
                      let self,
                      self.generation == requestedGeneration else { return }
                self.state = .unavailable(locationModel.authorization)
                return
            }

            do {
                let bounds = Self.searchBounds(around: coordinate)
                let area = try await networkRepository.viewport(in: bounds)
                try Task.checkCancellation()

                guard let self, self.generation == requestedGeneration else { return }
                guard let station = Self.nearestStation(
                    in: area,
                    to: coordinate
                ) else {
                    self.state = .empty
                    return
                }

                self.state = .resolved(ReportStationSelection(
                    station: station,
                    coordinate: coordinate,
                    source: .automatic
                ))
            } catch is CancellationError {
            } catch {
                guard let self, self.generation == requestedGeneration else { return }
                self.state = .error(error.via)
            }
        }
    }

    private static func searchBounds(
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

    private static func nearestStation(
        in area: StationsArea,
        to coordinate: GeoCoordinate
    ) -> ReportStation? {
        let routesByID = Dictionary(uniqueKeysWithValues: area.routes.map { ($0.id, $0) })

        return area.stations.compactMap { station -> (station: ReportStation, distance: Double)? in
            let routes = station.routeIDs.compactMap { routesByID[$0] }
            guard !routes.isEmpty else { return nil }

            return (
                ReportStation(networkStation: station, routes: routes),
                station.coordinate.metersAway(from: coordinate)
            )
        }
        .min { $0.distance < $1.distance }?
        .station
    }
}
