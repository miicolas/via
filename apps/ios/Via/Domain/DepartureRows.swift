import Foundation

struct WaitTimes: Equatable, Sendable {
    let primaryMinutes: Int
    let followingMinutes: [Int]

    var followingLabel: String? {
        guard !followingMinutes.isEmpty else { return nil }
        return "puis " + followingMinutes.map(String.init).joined(separator: " et ") + " min"
    }
}

struct DepartureDirectionDescriptor: Identifiable, Equatable, Sendable {
    let id: String
    let destination: String
    let wait: WaitTimes?
}

struct DepartureRowDescriptor: Identifiable, Equatable, Sendable {
    let id: String
    let route: RouteBadge
    let directions: [DepartureDirectionDescriptor]
}

func waitTimes(for departures: [String], now: Date) -> WaitTimes? {
    let grace: TimeInterval = 30
    let minutes = departures
        .compactMap { $0.iso8601Date?.timeIntervalSince(now) }
        .filter { $0 > -grace }
        .map { max(0, Int(floor($0 / 60))) }

    guard let primary = minutes.first else { return nil }
    return WaitTimes(primaryMinutes: primary, followingMinutes: Array(minutes.dropFirst().prefix(2)))
}

func departureRows(groups: [DepartureGroup], now: Date) -> [DepartureRowDescriptor] {
    var grouped: [String: [DepartureGroup]] = [:]
    for group in groups {
        grouped[group.route.id, default: []].append(group)
    }

    return grouped.values.compactMap { routeGroups in
        guard let route = routeGroups.first?.route else { return nil }
        let directions = routeGroups.map { group in
            DepartureDirectionDescriptor(
                id: "\(route.id)-\(group.destination)",
                destination: group.destination,
                wait: waitTimes(for: group.departures, now: now)
            )
        }

        guard directions.contains(where: { $0.wait != nil }) else { return nil }
        return DepartureRowDescriptor(id: route.id, route: route, directions: directions)
    }
    .sorted { left, right in
        let leftNumber = Int(left.route.shortName.filter(\.isNumber)) ?? Int.max
        let rightNumber = Int(right.route.shortName.filter(\.isNumber)) ?? Int.max
        if leftNumber != rightNumber { return leftNumber < rightNumber }
        return left.route.shortName.localizedStandardCompare(right.route.shortName) == .orderedAscending
    }
}
