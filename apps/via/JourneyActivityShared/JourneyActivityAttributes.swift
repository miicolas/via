import ActivityKit
import Foundation

struct JourneyActivityAttributes: ActivityAttributes, Sendable {
    struct ContentState: Codable, Hashable, Sendable {
        let phaseTitle: String
        let instructionTitle: String
        let instructionDetail: String?
        let nextAction: String?
        let routeShortName: String?
        let routeColorHex: String?
        let arrivalAt: Date
        let updatedAt: Date
        let isOffline: Bool
        let isArrived: Bool
    }

    let journeyID: String
    let destinationName: String
}
