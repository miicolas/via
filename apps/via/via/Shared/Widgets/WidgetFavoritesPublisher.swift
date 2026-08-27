import Foundation
import WidgetKit

/// Publishes the favourites snapshot the widgets and controls read.
///
/// The app is the only writer. Widgets get a refresh budget from the system, so
/// a reload is asked for only when the *drawn* content moved — renaming a
/// favourite or a line falling over, never a screen simply being opened.
@MainActor
final class WidgetFavoritesPublisher {
    private let store: WidgetFavoritesStore
    private let reloadWidgets: @MainActor () -> Void
    private let now: @MainActor () -> Date

    init(
        store: WidgetFavoritesStore = WidgetFavoritesStore(),
        reloadWidgets: @escaping @MainActor () -> Void = {
            WidgetCenter.shared.reloadAllTimelines()
            ControlCenter.shared.reloadAllControls()
        },
        now: @escaping @MainActor () -> Date = { .now }
    ) {
        self.store = store
        self.reloadWidgets = reloadWidgets
        self.now = now
    }

    /// `linesFetchedAt` is the board's own timestamp, not this call's: a widget
    /// reporting freshness reports the age of the conditions, and the board may
    /// have been read minutes before the screen that publishes it.
    func publish(
        places: [SavedPlace],
        destinations: [SavedDestination],
        lines: [LineStatus],
        linesFetchedAt: Date?
    ) {
        let published = store.read()
        let projected = WidgetFavoritesProjection.lines(lines)
        // A board that has never loaded is not an empty board. Without this,
        // every cold launch would blank the saved-lines widget until the first
        // response landed. Once the board *has* loaded, an empty list is the
        // answer — that is the traveller removing their last saved line.
        let resolvedLines = projected.isEmpty && linesFetchedAt == nil
            ? published.lines
            : projected

        let snapshot = WidgetFavoritesSnapshot(
            journeys: WidgetFavoritesProjection.journeys(
                places: places,
                destinations: destinations
            ),
            lines: resolvedLines,
            capturedAt: now(),
            linesFetchedAt: linesFetchedAt ?? published.linesFetchedAt
        )

        guard store.write(snapshot) else { return }
        reloadWidgets()
    }
}
