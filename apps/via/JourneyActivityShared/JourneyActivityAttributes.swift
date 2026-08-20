import ActivityKit
import Foundation

struct JourneyActivityAttributes: ActivityAttributes, Sendable {
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
        let isArrived: Bool
        /// 0…1 across the whole journey, mirroring the in-app progress bar.
        let progressFraction: Double
        /// Stops left before getting off, when the current leg is a ridden one.
        let stopsRemaining: Int?
        /// Where to get off, so the lock screen answers it without unlocking.
        let alightStopName: String?
    }

    let journeyID: String
}
