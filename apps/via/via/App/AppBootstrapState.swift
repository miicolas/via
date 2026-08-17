import Foundation
import OSLog

@MainActor
enum AppBootstrapState {
    case preview
    case ready(AppDependencies)
    case failed(ViaError)

    static func bootstrap(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        loadConfiguration: () throws -> AppConfiguration = { try .bundled() },
        buildDependencies: @MainActor (AppConfiguration) throws -> AppDependencies = AppDependencies.live
    ) -> AppBootstrapState {
        if environment["XCODE_RUNNING_FOR_PLAYGROUNDS"] == "1"
            || environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            return .preview
        }

        do {
            let configuration = try loadConfiguration()
            return .ready(try buildDependencies(configuration))
        } catch {
            let error = error.via
            ViaLog.app.fault(
                "Invalid configuration: \(String(describing: error), privacy: .public)"
            )
            return .failed(error)
        }
    }
}
