import SwiftUI
import OSLog

@main
struct ViaApp: App {
    private let dependencies: AppDependencies
    private let configurationError: String?

    init() {
        do {
            dependencies = try AppDependencies.live(configuration: .bundled())
            configurationError = nil
        } catch {
            dependencies = .preview
            configurationError = String(describing: error)
            ViaLog.app.fault("Invalid configuration: \(String(describing: error), privacy: .public)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
