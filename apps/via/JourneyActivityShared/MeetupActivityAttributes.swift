import ActivityKit
import Foundation

/// The rendez-vous activity deliberately contains no route geometry, address,
/// token, encrypted payload, or coordinate. It is safe to send through APNs.
struct MeetupActivityAttributes: ActivityAttributes, Sendable {
    enum GroupState: String, Codable, Hashable, Sendable {
        case preparing
        case converging
        case joined
        case fallback
        case arrived
        case ended
    }

    enum JoinZone: String, Codable, Hashable, Sendable {
        case front
        case middle
        case rear

        var title: String {
            switch self {
            case .front: "avant"
            case .middle: "milieu"
            case .rear: "arrière"
            }
        }
    }

    struct ContentState: Codable, Hashable, Sendable {
        let nextDepartureAt: Date?
        let joinPersonName: String?
        let joinStationName: String?
        let joinZone: JoinZone?
        /// Signed difference from the requested arrival, rounded in minutes.
        let arrivalDeltaMinutes: Int
        let expectedArrivalAt: Date
        let groupState: GroupState
        let groupSummary: String
    }

    let meetupID: String
    let destinationName: String

    var meetupURL: URL? {
        var components = URLComponents()
        components.scheme = "via"
        components.host = "meetup"
        components.path = "/\(meetupID)"
        return components.url
    }
}
