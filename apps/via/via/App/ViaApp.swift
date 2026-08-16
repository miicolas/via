import SwiftUI

@main
struct ViaApp: App {
    private let bootstrapState: AppBootstrapState

    init() {
        bootstrapState = .bootstrap()
    }

    var body: some Scene {
        WindowGroup {
            switch bootstrapState {
            case .ready(let dependencies):
                AuthenticationGateView(viewModel: dependencies.authSession) {
                    RootView(
                        dependencies: dependencies.root,
                        authViewModel: dependencies.authSession
                    )
                }
            case .failed(let error):
                ConfigurationErrorView(error: error)
            }
        }
    }
}
