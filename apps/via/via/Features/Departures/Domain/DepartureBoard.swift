import Foundation

struct DepartureGroup: Sendable, Hashable, Identifiable {
    let route: RouteBadge
    let destination: String
    let departures: [Date]

    var id: String { "\(route.id.rawValue):\(destination)" }
}

struct DepartureBoard: Sendable, Hashable {
    enum Source: String, Sendable, Hashable { case realtime, theoretical, unavailable }

    let source: Source
    let generatedAt: Date
    let groups: [DepartureGroup]
}

