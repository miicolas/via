import Foundation

protocol DeparturesRepository: Sendable {
    func board(stationID: StationID) async throws -> DepartureBoard
}

struct LiveDeparturesRepository: DeparturesRepository {
    let transport: ViaTransport

    func board(stationID: StationID) async throws -> DepartureBoard {
        try await transport.perform("departures") { client in
            let input = Operations.departures_period_forStation.Input(
                query: .init(stationId: stationID.rawValue)
            )
            switch try await client.departures_period_forStation(input) {
            case .ok(let response):
                return try transport.convert(response.body.json, to: DepartureBoardDTO.self).domain()
            case .undocumented(let statusCode, _):
                throw ViaTransport.error(for: statusCode)
            }
        }
    }
}

struct InMemoryDeparturesRepository: DeparturesRepository {
    var board: DepartureBoard = .init(source: .unavailable, generatedAt: .now, groups: [])
    func board(stationID: StationID) async throws -> DepartureBoard { board }
}
