import Foundation

enum NavigoAvailability: Equatable, Sendable {
    case unavailable
}

@MainActor
protocol NavigoClient {
    var availability: NavigoAvailability { get }
}

@MainActor
struct UnavailableNavigoClient: NavigoClient {
    let availability: NavigoAvailability = .unavailable
}
