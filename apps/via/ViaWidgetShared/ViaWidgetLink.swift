import Foundation

/// The `via://` links widgets and controls open.
///
/// Built here rather than at each tile so the extension has one place naming
/// the app's routes, and parsed by `MapRoute` on the other side.
/// `ViaWidgetLinkTests` round-trips every builder through the parser, because a
/// drift between the two does not fail to build — it ships a widget that opens
/// the app on nothing.
enum ViaWidgetLink {
    static let scheme = "via"

    /// Distinguishes a home/work place from a saved destination inside the one
    /// favourite token the widget carries. `SavedPlace` ids are server-shaped
    /// and a `SavedDestination` id is a UUID, so the prefix is what lets the
    /// app resolve either without a second query item.
    static let placeTokenPrefix = "place:"

    /// Starts the journey to a saved favourite.
    static func favoriteJourney(id: String) -> URL {
        url(
            host: "journey",
            queryItems: [
                URLQueryItem(name: "mode", value: "favorite"),
                URLQueryItem(name: "favoriteId", value: id),
            ]
        )
    }

    /// Opens one line's detail.
    static func line(routeID: String) -> URL {
        url(host: "line", queryItems: [URLQueryItem(name: "routeId", value: routeID)])
    }

    /// Opens the Lignes tab.
    static var lines: URL { url(host: "lines") }

    /// Opens the Recherche tab, ready for a destination.
    static var search: URL { url(host: "search") }

    private static func url(host: String, queryItems: [URLQueryItem] = []) -> URL {
        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        components.queryItems = queryItems.isEmpty ? nil : queryItems
        // The fallback opens the app on its root rather than nowhere; the
        // components above cannot actually fail to compose a URL.
        return components.url ?? URL(string: "\(scheme)://search")!
    }
}
