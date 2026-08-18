import Foundation

protocol LineStatusRepository: Sendable {
    func statuses() async throws -> LineStatusBoard
    func searchLines(query: String) async throws -> LineStatusBoard
    func detail(lineID: RouteID) async throws -> LineDetail
}

struct LiveLineStatusRepository: LineStatusRepository {
    let transport: APITransport

    func statuses() async throws -> LineStatusBoard {
        try await transport.perform("lines") { client in
            switch try await client.lines_period_statuses(.init()) {
            case .ok(let response):
                return try transport.convert(response.body.json, to: LineStatusBoardDTO.self).domain()
            case .undocumented(let statusCode, _):
                throw APITransport.error(for: statusCode)
            }
        }
    }

    func searchLines(query: String) async throws -> LineStatusBoard {
        try await transport.perform("lines") { client in
            let input = Operations.lines_period_search.Input(query: .init(q: query, limit: 10))
            switch try await client.lines_period_search(input) {
            case .ok(let response):
                return try transport.convert(response.body.json, to: LineStatusBoardDTO.self).domain()
            case .undocumented(let statusCode, _):
                throw APITransport.error(for: statusCode)
            }
        }
    }

    func detail(lineID: RouteID) async throws -> LineDetail {
        try await transport.perform("lines") { client in
            let input = Operations.lines_period_detail.Input(query: .init(lineId: lineID.rawValue))
            switch try await client.lines_period_detail(input) {
            case .ok(let response):
                return try transport.convert(response.body.json, to: LineDetailDTO.self).domain()
            case .undocumented(let statusCode, _):
                throw APITransport.error(for: statusCode)
            }
        }
    }
}
