import Foundation

struct DepartureBoardDTO: Decodable {
    struct Group: Decodable {
        let route: RouteBadgeDTO
        let destination: String
        let departures: [Date]
    }

    let source: String
    let generatedAt: Date
    let groups: [Group]

    func domain() throws -> DepartureBoard {
        guard let source = DepartureBoard.Source(rawValue: source) else {
            throw ViaError.decoding
        }
        return DepartureBoard(
            source: source,
            generatedAt: generatedAt,
            groups: try groups.map {
                DepartureGroup(
                    route: try $0.route.domain(),
                    destination: $0.destination,
                    departures: $0.departures
                )
            }
        )
    }
}
