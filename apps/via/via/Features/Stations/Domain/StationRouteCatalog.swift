import Foundation

/// Resolves and orders a station's routes consistently for both nearest-
/// station overviews and map annotations.
struct StationRouteCatalog {
    private let routesByID: [RouteID: RouteBadge]

    init(routes: [RouteBadge]) {
        routesByID = routes.reduce(into: [:]) { result, route in
            result[route.id] = route
        }
    }

    func routes(for routeIDs: [RouteID]) -> [RouteBadge] {
        var seenRouteIDs: Set<RouteID> = []
        return routeIDs
            .filter { seenRouteIDs.insert($0).inserted }
            .compactMap { routesByID[$0] }
            .sorted { lhs, rhs in
                if lhs.mode != rhs.mode { return lhs.mode < rhs.mode }
                return lhs.shortName.localizedStandardCompare(rhs.shortName) == .orderedAscending
            }
    }
}
