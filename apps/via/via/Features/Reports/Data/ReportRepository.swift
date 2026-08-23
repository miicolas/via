import Foundation

protocol ReportRepository: Sendable {
    func submit(_ submission: ReportSubmission) async throws -> StationLiveStatus
    func stationStatus(stationID: StationID, lineID: RouteID?, vehicleID: String?) async throws -> StationLiveStatus
}

actor InMemoryReportRepository: ReportRepository {
    private var storedSubmissions: [ReportSubmission] = []

    func submit(_ submission: ReportSubmission) async throws -> StationLiveStatus {
        storedSubmissions.append(submission)
        return .empty(stationID: submission.context.station.id, at: submission.submittedAt)
    }

    func stationStatus(
        stationID: StationID,
        lineID: RouteID?,
        vehicleID: String?
    ) async throws -> StationLiveStatus {
        .empty(stationID: stationID)
    }

    func submissions() -> [ReportSubmission] {
        storedSubmissions
    }
}

struct LiveReportRepository: ReportRepository {
    let transport: APITransport

    func submit(_ submission: ReportSubmission) async throws -> StationLiveStatus {
        try await transport.perform("reports.submit") { client in
            let input = Operations.reports_period_submit.Input(body: .json(.init(
                id: submission.id.uuidString.lowercased(),
                stationId: submission.context.station.id.rawValue,
                category: .init(rawValue: submission.category.rawValue)!,
                value: valuePayload(submission.value),
                lineId: submission.context.lineID?.rawValue,
                journeyId: submission.context.journeyID?.rawValue,
                vehicleId: submission.context.vehicleID
            )))
            switch try await client.reports_period_submit(input) {
            case .ok(let response):
                return try transport.convert(response.body.json, to: StationLiveStatus.self)
            case .undocumented(let statusCode, _):
                throw APITransport.error(for: statusCode)
            }
        }
    }

    func stationStatus(
        stationID: StationID,
        lineID: RouteID?,
        vehicleID: String?
    ) async throws -> StationLiveStatus {
        try await transport.perform("reports.stationStatus") { client in
            let input = Operations.reports_period_stationStatus.Input(query: .init(
                stationId: stationID.rawValue,
                lineId: lineID?.rawValue,
                vehicleId: vehicleID
            ))
            switch try await client.reports_period_stationStatus(input) {
            case .ok(let response):
                return try transport.convert(response.body.json, to: StationLiveStatus.self)
            case .undocumented(let statusCode, _):
                throw APITransport.error(for: statusCode)
            }
        }
    }

    private func valuePayload(_ value: ReportValue) -> Operations.reports_period_submit.Input.Body.jsonPayload.valuePayload {
        switch value {
        case .occurrence: .occurrence
        case .resolved: .resolved
        case .crowding(let level): .init(rawValue: level.rawValue)!
        }
    }
}
