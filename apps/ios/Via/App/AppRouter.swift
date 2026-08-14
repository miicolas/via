import Observation

enum AppRoute: Hashable, Codable, Sendable {
    case station(id: String)
}

@MainActor
@Observable
final class AppRouter {
    var path: [AppRoute] = []
}
