import Foundation

struct StationCrowdingDTO: Decodable {
    struct HourDTO: Decodable {
        let hour: Int
        let ratio: Double
        let level: String
    }

    struct ProfilesDTO: Decodable {
        let weekday: [HourDTO]
        let saturday: [HourDTO]
        let sunday: [HourDTO]
    }

    let profiles: ProfilesDTO?

    /// `nil` is the legitimate "no profile" answer for a bus stop, not an error.
    func domain() throws -> StationCrowding? {
        guard let profiles else { return nil }
        return StationCrowding(
            weekday: try profiles.weekday.map(Self.hour),
            saturday: try profiles.saturday.map(Self.hour),
            sunday: try profiles.sunday.map(Self.hour)
        )
    }

    private static func hour(_ dto: HourDTO) throws -> CrowdingHour {
        guard let level = PeakLevel(rawValue: dto.level) else {
            throw ViaError.decoding
        }
        return CrowdingHour(hour: dto.hour, ratio: dto.ratio, level: level)
    }
}
