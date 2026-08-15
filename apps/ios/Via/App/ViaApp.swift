import SwiftUI

@main
struct ViaApp: App {
    private let dependencies: AppDependencies
    private let metricsSubscriber: ViaMetricsSubscriber

    init() {
        let dependencies = AppDependencies.live()
        self.dependencies = dependencies
        self.metricsSubscriber = ViaMetricsSubscriber(
            logger: ViaLogger(
                category: "metrics",
                verbose: dependencies.featureFlags.verboseLoggingEnabled
            )
        )
    }

    var body: some Scene {
        WindowGroup {
            RootView(dependencies: dependencies)
        }
    }
}
