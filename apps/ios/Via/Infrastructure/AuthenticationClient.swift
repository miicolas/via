import Foundation

enum AuthenticationAvailability: Equatable, Sendable {
    case unavailable
}

@MainActor
protocol AuthenticationClient {
    var availability: AuthenticationAvailability { get }
}

@MainActor
struct UnavailableAuthenticationClient: AuthenticationClient {
    let availability: AuthenticationAvailability = .unavailable
}
