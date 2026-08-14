import Foundation

@MainActor
struct AppDependencies {
    let transitAPI: any TransitAPI
    let locationProvider: any LocationProviding
    let chatClient: any ChatClient
    let isDemo: Bool

    static func live() -> AppDependencies {
        let identity = ClientIdentityStore().identifier
        let baseURL = URL(string: ProcessInfo.processInfo.environment["VIA_API_URL"] ?? "http://localhost:3000")!

        #if DEBUG
        let isDemo = ProcessInfo.processInfo.arguments.contains("--via-demo")
        #else
        let isDemo = false
        #endif

        let api: any TransitAPI
        if isDemo {
            api = DemoTransitAPI()
        } else {
            api = URLSessionTransitAPI(baseURL: baseURL, clientIdentifier: identity)
        }

        let chatClient: any ChatClient = isDemo
            ? DemoChatClient(transitAPI: api)
            : URLSessionChatClient(baseURL: baseURL, clientIdentifier: identity)

        return AppDependencies(
            transitAPI: api,
            locationProvider: isDemo
                ? DemoLocationProvider()
                : LocationClient(),
            chatClient: chatClient,
            isDemo: isDemo
        )
    }
}
