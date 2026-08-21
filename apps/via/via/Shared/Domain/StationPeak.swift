import Foundation

enum PeakLevel: String, Codable, Sendable, Hashable {
    case off
    case moderate
    case peak
}

struct StationPeak: Codable, Sendable, Hashable {
    let ratio: Double
    let level: PeakLevel
    let label: String
    let stationName: String?

    init(
        ratio: Double,
        level: PeakLevel,
        label: String,
        stationName: String? = nil
    ) {
        self.ratio = ratio
        self.level = level
        self.label = label
        self.stationName = stationName
    }
}
