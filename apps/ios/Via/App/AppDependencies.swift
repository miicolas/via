import Foundation

@MainActor
struct AppDependencies {
    let transitAPI: any TransitAPI
    let locationProvider: any LocationProviding

    static func live() -> AppDependencies {
        let identity = ClientIdentityStore().identifier
        let baseURL = URL(string: ProcessInfo.processInfo.environment["VIA_API_URL"] ?? "http://localhost:3000")!

        let api: any TransitAPI
        if ProcessInfo.processInfo.arguments.contains("--via-demo") {
            api = DemoTransitAPI()
        } else {
            api = URLSessionTransitAPI(baseURL: baseURL, clientIdentifier: identity)
        }

        return AppDependencies(
            transitAPI: api,
            locationProvider: LocationClient()
        )
    }
}
