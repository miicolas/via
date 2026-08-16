import Foundation

struct DepartureDirectionSnapshot: Identifiable, Sendable, Hashable {
    let destination: String
    let minutes: [Int]

    var id: String { destination }
}

func departureDirectionSnapshots(
    groups: [DepartureGroup],
    now: Date
) -> [DepartureDirectionSnapshot] {
    groups.compactMap { group in
        let minutes = group.departures
            .sorted()
            .map { $0.timeIntervalSince(now) }
            .filter { $0 > -30 }
            .prefix(3)
            .map { max(0, Int(floor($0 / 60))) }

        guard !minutes.isEmpty else { return nil }
        return DepartureDirectionSnapshot(
            destination: group.destination,
            minutes: Array(minutes)
        )
    }
}
