import Foundation

struct DepartureBoardDTO: Decodable {
    struct Item: Decodable {
        let id: String
        let scheduledAt: Date?
        let expectedAt: Date?
        let delaySeconds: Int?
        let status: String
    }

    struct Group: Decodable {
        let route: RouteBadgeDTO
        let destination: String
        let departures: [Date]
        let departureItems: [Item]?
    }

    let source: String
    let generatedAt: Date
    let fetchedAt: Date?
    let groups: [Group]

    func domain() throws -> DepartureBoard {
        guard let source = DepartureBoard.Source(rawValue: source) else {
            throw ViaError.decoding
        }
        return DepartureBoard(
            source: source,
            generatedAt: generatedAt,
            fetchedAt: fetchedAt,
            groups: try groups.map {
                let route = try $0.route.domain()
                if let departureItems = $0.departureItems {
                    return DepartureGroup(
                        route: route,
                        destination: $0.destination,
                        departureItems: try departureItems.map { item in
                            guard let status = DepartureStatus(rawValue: item.status) else {
                                throw ViaError.decoding
                            }
                            return DepartureItem(
                                id: item.id,
                                scheduledAt: item.scheduledAt,
                                expectedAt: item.expectedAt,
                                delaySeconds: item.delaySeconds,
                                status: status
                            )
                        }
                    )
                }

                return DepartureGroup(
                    route: route,
                    destination: $0.destination,
                    departures: $0.departures,
                    status: source == .theoretical ? .scheduled : .noReport
                )
            }
        )
    }
}
