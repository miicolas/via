import Foundation
import OSLog

enum ViaLog {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "dev.via.app"

    static let app = Logger(subsystem: subsystem, category: "app")
    static let network = Logger(subsystem: subsystem, category: "network")
    static let location = Logger(subsystem: subsystem, category: "location")

    static func requestStarted(_ operation: StaticString) -> OSSignpostID {
        let identifier = OSSignpostID(log: signpostLog)
        os_signpost(.begin, log: signpostLog, name: operation, signpostID: identifier)
        return identifier
    }

    static func requestFinished(_ operation: StaticString, identifier: OSSignpostID) {
        os_signpost(.end, log: signpostLog, name: operation, signpostID: identifier)
    }

    private static let signpostLog = OSLog(subsystem: subsystem, category: .pointsOfInterest)
}

