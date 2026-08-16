import SwiftUI
import OSLog

@main
struct ViaApp: App {
    private let dependencies: AppDependencies
    private let networkViewModel: NetworkViewModel
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
        networkViewModel = dependencies.makeNetworkViewModel()
    }

    var body: some Scene {
        WindowGroup {
            AuthenticationGateView(viewModel: dependencies.authSession) {
                RootView(
                    networkViewModel: networkViewModel,
                    authViewModel: dependencies.authSession,
                    account: dependencies.account,
                    makeDeparturesViewModel: {
                        dependencies.makeDeparturesViewModel(stationID: $0)
                    }
                )
            }
        }
    }
}
