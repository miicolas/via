import Foundation

protocol DeparturesRepository: Sendable {
    func board(stationID: StationID) async throws -> DepartureBoard
}

struct LiveDeparturesRepository: DeparturesRepository {
    let client: any ViaAPIClient
    func board(stationID: StationID) async throws -> DepartureBoard { try await client.departures(stationID: stationID) }
}

struct InMemoryDeparturesRepository: DeparturesRepository {
    var board: DepartureBoard = .init(source: .unavailable, generatedAt: .now, groups: [])
    func board(stationID: StationID) async throws -> DepartureBoard { board }
}
