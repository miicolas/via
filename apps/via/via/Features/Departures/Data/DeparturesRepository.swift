import Foundation

protocol DeparturesRepository: Sendable {
    func board(stationID: StationID) async throws -> DepartureBoard
    /// Loads the service-day board for one line at a station.
    func board(stationID: StationID, routeID: RouteID) async throws -> DepartureBoard
}

extension DeparturesRepository {
    /// Previews and older repository adapters already carry a complete board;
    /// filtering it here keeps those seams source-compatible while the live
    /// adapter can ask the API for the deeper line-specific payload.
    func board(stationID: StationID, routeID: RouteID) async throws -> DepartureBoard {
        try await board(stationID: stationID)
    }
}

struct LiveDeparturesRepository: DeparturesRepository {
    let transport: APITransport

    func board(stationID: StationID) async throws -> DepartureBoard {
        try await requestBoard(stationID: stationID, routeID: nil)
    }

    func board(stationID: StationID, routeID: RouteID) async throws -> DepartureBoard {
        try await requestBoard(stationID: stationID, routeID: routeID)
    }

    private func requestBoard(stationID: StationID, routeID: RouteID?) async throws -> DepartureBoard {
        try await transport.perform("departures") { client in
            let input = Operations.departures_period_forStation.Input(
                query: .init(
                    stationId: stationID.rawValue,
                    routeId: routeID?.rawValue
                )
            )
            switch try await client.departures_period_forStation(input) {
            case .ok(let response):
                return try transport.convert(response.body.json, to: DepartureBoardDTO.self).domain()
            case .undocumented(let statusCode, _):
                throw APITransport.error(for: statusCode)
            }
        }
    }
}

struct InMemoryDeparturesRepository: DeparturesRepository {
    var board: DepartureBoard = .init(source: .unavailable, generatedAt: .now, groups: [])
    func board(stationID: StationID) async throws -> DepartureBoard { board }
}
