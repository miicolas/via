import ActivityKit
import Foundation

struct JourneyActivityAttributes: ActivityAttributes, Sendable {
    enum Phase: String, Codable, Hashable, Sendable {
        case scheduled
        case underway
        case paused
        case arrived
        case ended
    }

    /// Everything the widget needs to draw a line badge without reaching into
    /// the app's domain models, which the extension does not link.
    struct LineBadge: Codable, Hashable, Sendable {
        let shortName: String
        let colorHex: String
        let textColorHex: String
    }

    /// The live station marker mirrored from the in-app journey rail.
    ///
    /// It intentionally carries presentation-ready values: the extension
    /// cannot link the app's journey models, and ActivityKit payloads must stay
    /// self-contained while the app is suspended.
    struct StopProgress: Codable, Hashable, Sendable {
        enum Status: String, Codable, Hashable, Sendable {
            case current
            case next
        }

        let stopName: String
        let alightingStopName: String
        let remainingStopCount: Int
        let status: Status
    }

    struct ContentState: Codable, Hashable, Sendable {
        let phaseTitle: String
        let instructionTitle: String
        let instructionDetail: String?
        let nextAction: String?
        /// The line in play right now: the one being ridden, or the one being
        /// walked or waited towards, so the badge stays on screen for the whole
        /// leg instead of only while riding.
        let line: LineBadge?
        /// The line of the "Ensuite" step, when it differs from `line`.
        let nextLine: LineBadge?
        let arrivalAt: Date
        let isOffline: Bool
        let isArrived: Bool
        /// A stable semantic phase lets the widget render a live countdown
        /// without parsing the localized `phaseTitle`.
        ///
        /// Optional decoding keeps an activity created by an older app build
        /// renderable while it is being dismissed after an update.
        let phase: Phase?
        /// The scheduled departure used by the countdown in the activity.
        /// Optional decoding keeps the state backward compatible with the
        /// first local ActivityKit payloads.
        let departureAt: Date?
        /// The station reached from the latest fresh Core Location fix.
        /// Optional decoding keeps activities started by an older build alive.
        let stopProgress: StopProgress?

        init(
            phaseTitle: String,
            instructionTitle: String,
            instructionDetail: String?,
            nextAction: String?,
            line: LineBadge?,
            nextLine: LineBadge?,
            arrivalAt: Date,
            isOffline: Bool,
            isArrived: Bool,
            phase: Phase? = nil,
            departureAt: Date? = nil,
            stopProgress: StopProgress? = nil
        ) {
            self.phaseTitle = phaseTitle
            self.instructionTitle = instructionTitle
            self.instructionDetail = instructionDetail
            self.nextAction = nextAction
            self.line = line
            self.nextLine = nextLine
            self.arrivalAt = arrivalAt
            self.isOffline = isOffline
            self.isArrived = isArrived
            self.phase = phase
            self.departureAt = departureAt
            self.stopProgress = stopProgress
        }

        private enum CodingKeys: String, CodingKey {
            case phaseTitle
            case instructionTitle
            case instructionDetail
            case nextAction
            case line
            case nextLine
            case arrivalAt
            case isOffline
            case isArrived
            case phase
            case departureAt
            case stopProgress
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            phaseTitle = try container.decode(String.self, forKey: .phaseTitle)
            instructionTitle = try container.decode(String.self, forKey: .instructionTitle)
            instructionDetail = try container.decodeIfPresent(String.self, forKey: .instructionDetail)
            nextAction = try container.decodeIfPresent(String.self, forKey: .nextAction)
            line = try container.decodeIfPresent(LineBadge.self, forKey: .line)
            nextLine = try container.decodeIfPresent(LineBadge.self, forKey: .nextLine)
            arrivalAt = try container.decode(Date.self, forKey: .arrivalAt)
            isOffline = try container.decode(Bool.self, forKey: .isOffline)
            isArrived = try container.decode(Bool.self, forKey: .isArrived)
            phase = try container.decodeIfPresent(Phase.self, forKey: .phase)
            departureAt = try container.decodeIfPresent(Date.self, forKey: .departureAt)
            stopProgress = try container.decodeIfPresent(StopProgress.self, forKey: .stopProgress)
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(phaseTitle, forKey: .phaseTitle)
            try container.encode(instructionTitle, forKey: .instructionTitle)
            try container.encodeIfPresent(instructionDetail, forKey: .instructionDetail)
            try container.encodeIfPresent(nextAction, forKey: .nextAction)
            try container.encodeIfPresent(line, forKey: .line)
            try container.encodeIfPresent(nextLine, forKey: .nextLine)
            try container.encode(arrivalAt, forKey: .arrivalAt)
            try container.encode(isOffline, forKey: .isOffline)
            try container.encode(isArrived, forKey: .isArrived)
            try container.encodeIfPresent(phase, forKey: .phase)
            try container.encodeIfPresent(departureAt, forKey: .departureAt)
            try container.encodeIfPresent(stopProgress, forKey: .stopProgress)
        }
    }

    let journeyID: String

    /// ActivityKit hands this URL back to the app when the user taps the
    /// activity. The active mode is required so the app opens the running
    /// journey instead of silently ignoring the deep link.
    var journeyURL: URL? {
        var components = URLComponents()
        components.scheme = "via"
        components.host = "journey"
        components.path = "/\(journeyID)"
        components.queryItems = [URLQueryItem(name: "mode", value: "active")]
        return components.url
    }
}
