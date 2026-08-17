import OSLog

@MainActor
enum AppBootstrapState {
    case ready(AppDependencies)
    case failed(ViaError)

    static func bootstrap(
        loadConfiguration: () throws -> AppConfiguration = { try .bundled() },
        buildDependencies: @MainActor (AppConfiguration) throws -> AppDependencies = AppDependencies.live
    ) -> AppBootstrapState {
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
