import Foundation

protocol StationCrowdingRepository: Sendable {
    /// `nil` means the station has no validations profile (a bus stop, notably).
    func crowding(stationID: StationID) async throws -> StationCrowding?
}

struct LiveStationCrowdingRepository: StationCrowdingRepository {
    let transport: APITransport

    func crowding(stationID: StationID) async throws -> StationCrowding? {
        try await transport.perform("stationCrowding") { client in
            let input = Operations.network_period_stationCrowding.Input(
                query: .init(stationId: stationID.rawValue)
            )
            switch try await client.network_period_stationCrowding(input) {
            case .ok(let response):
                return try transport.convert(response.body.json, to: StationCrowdingDTO.self)
                    .domain()
            case .undocumented(let statusCode, _):
                throw APITransport.error(for: statusCode)
            }
        }
    }
}

struct InMemoryStationCrowdingRepository: StationCrowdingRepository {
    var crowding: StationCrowding?
    func crowding(stationID: StationID) async throws -> StationCrowding? { crowding }
}

extension StationCrowding {
    /// A believable métro shape — morning and evening rushes on weekdays,
    /// one broad afternoon dome on weekends — for previews and tests.
    static let preview: StationCrowding = {
        func profile(peaks: [(hour: Int, ratio: Double)], spread: Double) -> [CrowdingHour] {
            (0..<24).map { hour in
                let ratio = peaks
                    .map { peak in
                        peak.ratio * exp(-pow(Double(hour - peak.hour) / spread, 2))
                    }
                    .max() ?? 0
                let rounded = (ratio * 100).rounded() / 100
                let level: PeakLevel = rounded >= 0.8 ? .peak : rounded >= 0.5 ? .moderate : .off
                return CrowdingHour(hour: hour, ratio: rounded, level: level)
            }
        }
        return StationCrowding(
            weekday: profile(peaks: [(8, 1.0), (18, 0.9), (13, 0.45)], spread: 1.8),
            saturday: profile(peaks: [(15, 0.8), (11, 0.6)], spread: 3.2),
            sunday: profile(peaks: [(16, 0.6)], spread: 3.6)
        )
    }()
}
