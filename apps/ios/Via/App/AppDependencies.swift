import Foundation

@MainActor
struct AppDependencies {
    let transitAPI: any TransitAPI
    let locationProvider: any LocationProviding
    let chatClient: any ChatClient
    let featureFlags: NativeFeatureFlags

    static func live(processInfo: ProcessInfo = .processInfo) -> AppDependencies {
        let configuration = NativeRuntimeConfiguration.live(processInfo: processInfo)
        let featureFlags = configuration.featureFlags
        let identity = ClientIdentityStore().identifier
        let clientMetadata = NativeClientMetadata.current
        let appLogger = ViaLogger(category: "app", verbose: featureFlags.verboseLoggingEnabled)
        appLogger.featureFlags(featureFlags)

        let api: any TransitAPI
        if featureFlags.usesDemoData {
            api = DemoTransitAPI()
        } else {
            api = OpenAPITransitAPI(
                baseURL: configuration.apiBaseURL,
                clientIdentifier: identity,
                clientMetadata: clientMetadata,
                logger: ViaLogger(category: "network", verbose: featureFlags.verboseLoggingEnabled)
            )
        }

        let chatClient: any ChatClient = featureFlags.usesDemoData
            ? DemoChatClient(transitAPI: api)
            : URLSessionChatClient(
                baseURL: configuration.apiBaseURL,
                clientIdentifier: identity,
                clientMetadata: clientMetadata,
                logger: ViaLogger(category: "chat", verbose: featureFlags.verboseLoggingEnabled)
            )

        return AppDependencies(
            transitAPI: api,
            locationProvider: featureFlags.usesDemoData
                ? DemoLocationProvider()
                : LocationClient(),
            chatClient: chatClient,
            featureFlags: featureFlags
        )
    }
}
