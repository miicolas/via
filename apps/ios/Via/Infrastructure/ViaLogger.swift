import OSLog

struct ViaLogger: Sendable {
    private let logger: Logger
    private let verbose: Bool

    init(category: String, verbose: Bool = false) {
        logger = Logger(subsystem: "dev.via.app", category: category)
        self.verbose = verbose
    }

    func featureFlags(_ flags: NativeFeatureFlags) {
        logger.info(
            "native flags chat=\(flags.chatEnabled, privacy: .public) classic_journeys=\(flags.classicJourneysEnabled, privacy: .public) natural_journeys=\(flags.naturalJourneysEnabled, privacy: .public) demo=\(flags.usesDemoData, privacy: .public)"
        )
    }

    func requestStarted(operation: String, path: String) {
        guard verbose else { return }
        logger.debug(
            "request started operation=\(operation, privacy: .public) path=\(path, privacy: .public)"
        )
    }

    func requestSucceeded(operation: String, path: String, durationMilliseconds: Int) {
        guard verbose else { return }
        logger.debug(
            "request succeeded operation=\(operation, privacy: .public) path=\(path, privacy: .public) duration_ms=\(durationMilliseconds, privacy: .public)"
        )
    }

    func requestFailed(operation: String, path: String, error: TransitAPIError) {
        logger.error(
            "request failed operation=\(operation, privacy: .public) path=\(path, privacy: .public) error=\(error.logLabel, privacy: .public)"
        )
    }
}
