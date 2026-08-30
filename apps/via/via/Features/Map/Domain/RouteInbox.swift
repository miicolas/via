import Foundation
import Observation

/// The one door every deep link enters through — a universal link, a custom
/// scheme URL, or a push notification's route.
///
/// The inbox buffers the latest route until the map shell exists to consume
/// it, so links that arrive during onboarding are not lost and no entry point
/// needs its own copy of the route switch.
@MainActor
@Observable
final class RouteInbox {
    private(set) var pending: MapRoute?

    /// Parses and buffers a URL; a URL that is not ours is ignored.
    func receive(_ url: URL) {
        guard let route = MapRoute(url: url) else { return }
        receive(route)
    }

    func receive(_ route: MapRoute) {
        pending = route
    }

    /// Hands over the buffered route exactly once.
    func consume() -> MapRoute? {
        defer { pending = nil }
        return pending
    }
}
