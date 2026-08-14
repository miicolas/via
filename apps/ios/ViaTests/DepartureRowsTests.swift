import Foundation
import Testing
@testable import Via

struct DepartureRowsTests {
    @Test
    func groupsPastDeparturesAndKeepsTwoFollowingTimes() {
        let route = RouteBadge(id: "1", shortName: "1", mode: .metro, color: "FFCD00", textColor: "161A18")
        let now = Date(timeIntervalSince1970: 1_750_000_000)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let departures = stride(from: 2, through: 20, by: 5).map {
            formatter.string(from: now.addingTimeInterval(Double($0 * 60)))
        }

        let rows = departureRows(
            groups: [DepartureGroup(route: route, destination: "La Défense", departures: departures)],
            now: now
        )

        #expect(rows.count == 1)
        #expect(rows[0].directions[0].wait?.primaryMinutes == 2)
        #expect(rows[0].directions[0].wait?.followingMinutes == [7, 12])
    }

    @Test
    func expiredGroupsAreNotRendered() {
        let route = RouteBadge(id: "1", shortName: "1", mode: .metro, color: "FFCD00", textColor: "161A18")
        let now = Date(timeIntervalSince1970: 1_750_000_000)
        let old = ISO8601DateFormatter().string(from: now.addingTimeInterval(-120))

        let rows = departureRows(
            groups: [DepartureGroup(route: route, destination: "La Défense", departures: [old])],
            now: now
        )

        #expect(rows.isEmpty)
    }
}
