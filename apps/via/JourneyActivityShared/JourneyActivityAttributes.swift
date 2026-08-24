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
        /// The cached timetable is moving the guidance cursor because a fresh
        /// live location is not currently available.
        let isEstimated: Bool
        let isArrived: Bool
        /// 0…1 across the whole journey, mirroring the in-app progress bar.
        let progressFraction: Double
        /// Stops left before getting off, when the current leg is a ridden one.
        let stopsRemaining: Int?
        /// Where to get off, so the lock screen answers it without unlocking.
        let alightStopName: String?
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
            isEstimated: Bool,
            progressFraction: Double,
            stopsRemaining: Int?,
            alightStopName: String?,
            phase: Phase? = nil,
            departureAt: Date? = nil
        ) {
            self.phaseTitle = phaseTitle
            self.instructionTitle = instructionTitle
            self.instructionDetail = instructionDetail
            self.nextAction = nextAction
            self.line = line
            self.nextLine = nextLine
            self.arrivalAt = arrivalAt
            self.isOffline = isOffline
            self.isEstimated = isEstimated
            self.isArrived = isArrived
            self.progressFraction = progressFraction
            self.stopsRemaining = stopsRemaining
            self.alightStopName = alightStopName
            self.phase = phase
            self.departureAt = departureAt
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
            case isEstimated
            case isArrived
            case progressFraction
            case stopsRemaining
            case alightStopName
            case phase
            case departureAt
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
            isEstimated = try container.decodeIfPresent(Bool.self, forKey: .isEstimated) ?? false
            isArrived = try container.decode(Bool.self, forKey: .isArrived)
            progressFraction = try container.decode(Double.self, forKey: .progressFraction)
            stopsRemaining = try container.decodeIfPresent(Int.self, forKey: .stopsRemaining)
            alightStopName = try container.decodeIfPresent(String.self, forKey: .alightStopName)
            phase = try container.decodeIfPresent(Phase.self, forKey: .phase)
            departureAt = try container.decodeIfPresent(Date.self, forKey: .departureAt)
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
            try container.encode(isEstimated, forKey: .isEstimated)
            try container.encode(isArrived, forKey: .isArrived)
            try container.encode(progressFraction, forKey: .progressFraction)
            try container.encodeIfPresent(stopsRemaining, forKey: .stopsRemaining)
            try container.encodeIfPresent(alightStopName, forKey: .alightStopName)
            try container.encodeIfPresent(phase, forKey: .phase)
            try container.encodeIfPresent(departureAt, forKey: .departureAt)
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
