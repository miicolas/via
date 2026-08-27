import AppIntents
import Foundation

/// The one intent every control button runs.
///
/// It carries the destination as a string rather than existing once per screen:
/// a control is a shortcut to a place in the app, and the places are already
/// named by `ViaWidgetLink`. `openAppWhenRun` brings Metyro forward — from the
/// Lock Screen that is also what asks for the device to be unlocked first.
struct OpenViaRouteIntent: AppIntent {
    static let title: LocalizedStringResource = "Ouvrir Metyro"
    static let description = IntentDescription("Ouvre Metyro sur l’écran demandé.")
    static let openAppWhenRun = true
    /// Not offered in Raccourcis: the traveller composes shortcuts from the
    /// screens, not from a URL they would have to spell themselves.
    static let isDiscoverable = false

    @Parameter(title: "Destination")
    var route: String

    init() {
        route = ViaWidgetLink.search.absoluteString
    }

    init(route: URL) {
        self.route = route.absoluteString
    }

    func perform() async throws -> some IntentResult {
        if let url = URL(string: route) {
            ViaWidgetRouteInbox().store(url)
        }
        return .result()
    }
}
