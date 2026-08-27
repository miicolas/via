import Foundation

/// Where a control button leaves the screen it wants opened.
///
/// A `ControlWidgetButton` cannot open a URL: it runs an App Intent. The intent
/// asks the system to bring the app forward and drops the route here; the shell
/// drains it on the next foreground. Same shape as the pending push route
/// `PushNotificationManager` already keeps, and for the same reason — the app
/// may not have a scene yet when the button is pressed.
struct ViaWidgetRouteInbox: Sendable {
    private static let key = "via.widget-pending-route.v1"

    private let defaults: UserDefaults?

    init(defaults: UserDefaults? = WidgetSharedContainer.defaults) {
        self.defaults = defaults
    }

    func store(_ url: URL) {
        defaults?.set(url.absoluteString, forKey: Self.key)
    }

    /// Reads and clears in one call: a route left behind would reopen the same
    /// screen on every foreground until the traveller pressed another button.
    func consume() -> URL? {
        guard let rawValue = defaults?.string(forKey: Self.key) else { return nil }
        defaults?.removeObject(forKey: Self.key)
        return URL(string: rawValue)
    }
}
