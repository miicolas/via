import Foundation

/// One hour of the station's habitual validations profile, normalised per
/// station and day type — 1 is that station's own busiest hour, never an
/// absolute traffic figure comparable across stations.
struct CrowdingHour: Codable, Sendable, Hashable {
    let hour: Int
    let ratio: Double
    let level: PeakLevel
}

/// The station's habitual 24-hour crowding, in the only three day shapes the
/// IDFM validations dataset distinguishes. Rail-only: a bus stop has none.
struct StationCrowding: Codable, Sendable, Hashable {
    let weekday: [CrowdingHour]
    let saturday: [CrowdingHour]
    let sunday: [CrowdingHour]
}
