import Foundation

extension NetworkRoute {
    var badge: RouteBadge {
        RouteBadge(
            id: id,
            shortName: shortName,
            mode: mode,
            color: color,
            textColor: textColor
        )
    }
}

func stationsOnRoute(_ route: NetworkRoute, from stations: [NetworkStation]) -> [NetworkStation] {
    stations.filter { $0.routeIds.contains(route.id) }
}
