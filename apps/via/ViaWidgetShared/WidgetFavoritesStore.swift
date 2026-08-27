import Foundation

/// The App Group side of the favourites snapshot: the app writes, the widget
/// extension reads.
struct WidgetFavoritesStore: Sendable {
    private static let key = "via.widget-favorites.v1"

    private let defaults: UserDefaults?

    init(defaults: UserDefaults? = WidgetSharedContainer.defaults) {
        self.defaults = defaults
    }

    /// The last snapshot the app published, or an empty one when nothing has
    /// been written yet — a first launch, or a build without the App Group.
    func read() -> WidgetFavoritesSnapshot {
        guard
            let data = defaults?.data(forKey: Self.key),
            let snapshot = try? JSONDecoder().decode(WidgetFavoritesSnapshot.self, from: data)
        else { return .empty }
        return snapshot
    }

    /// Writes the snapshot and answers whether the timelines are worth
    /// reloading.
    ///
    /// `false` when nothing a tile draws has changed. Widgets get a refresh
    /// budget from the system, and re-publishing the same favourites on every
    /// screen the traveller opens is how an app spends it on nothing.
    @discardableResult
    func write(_ snapshot: WidgetFavoritesSnapshot) -> Bool {
        guard let defaults, let data = try? JSONEncoder().encode(snapshot) else { return false }
        let previous = read()
        defaults.set(data, forKey: Self.key)
        return previous.journeys != snapshot.journeys || previous.lines != snapshot.lines
    }

    func clear() {
        defaults?.removeObject(forKey: Self.key)
    }
}
