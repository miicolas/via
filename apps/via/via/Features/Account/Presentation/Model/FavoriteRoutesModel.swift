import Foundation
import Observation

/// Resolves the lines serving each favorite station so the favorites list can
/// show correspondances rather than bookkeeping dates. Lookups go through the
/// tiled network area around the saved coordinate, which the repository
/// already caches for the map.
@MainActor
@Observable
final class FavoriteRoutesModel {
    private(set) var routesByStationID: [String: [RouteBadge]] = [:]

    @ObservationIgnored private let networkRepository: any NetworkRepository
    /// Stations already looked up, so reopening the screen doesn't refetch.
    /// A failed lookup leaves the set untouched to keep the retry open.
    @ObservationIgnored private var resolvedStationIDs: Set<String> = []

    init(networkRepository: any NetworkRepository) {
        self.networkRepository = networkRepository
    }

    func routes(for favorite: FavoriteStation) -> [RouteBadge] {
        routesByStationID[favorite.stationID] ?? []
    }

    /// Fills the missing stations one after another: neighbouring favorites
    /// share the repository's tiles, so the second lookup in a district is
    /// served from cache.
    func load(for favorites: [FavoriteStation]) async {
        for favorite in favorites {
            guard let coordinate = favorite.coordinate,
                  !resolvedStationIDs.contains(favorite.stationID) else { continue }

            do {
                let area = try await networkRepository.viewport(
                    in: Self.lookupBounds(around: coordinate)
                )
                try Task.checkCancellation()

                routesByStationID[favorite.stationID] = Self.routes(for: favorite, in: area)
                resolvedStationIDs.insert(favorite.stationID)
            } catch is CancellationError {
                return
            } catch {
                continue
            }
        }
    }

    private static func routes(
        for favorite: FavoriteStation,
        in area: StationsArea
    ) -> [RouteBadge] {
        guard let station = station(for: favorite, in: area) else { return [] }
        return StationRouteCatalog(routes: area.routes).routes(for: station.routeIDs)
    }

    /// Favorites store the map's identifier, so they usually match outright;
    /// the name match nearby covers a station saved before its identifier
    /// changed on the network side.
    private static func station(
        for favorite: FavoriteStation,
        in area: StationsArea
    ) -> NetworkStation? {
        if let exact = area.stations.first(where: { $0.id.rawValue == favorite.stationID }) {
            return exact
        }

        guard let coordinate = favorite.coordinate else { return nil }

        return area.stations
            .filter { $0.name.localizedCaseInsensitiveCompare(favorite.name) == .orderedSame }
            .min { lhs, rhs in
                lhs.coordinate.metersAway(from: coordinate)
                    < rhs.coordinate.metersAway(from: coordinate)
            }
    }

    private static func lookupBounds(
        around coordinate: GeoCoordinate,
        radiusMeters: Double = 400
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
