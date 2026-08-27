import Foundation

/// Everything a widget draws, in one comparable value.
///
/// The shell publishes on a `task(id:)` keyed on this rather than on each
/// screen appearing: the map's body is re-evaluated on every frame of a sheet
/// drag, and a re-publish there would spend the system's widget refresh budget
/// on a snapshot that did not move.
struct WidgetFavoritesSignature: Hashable, Sendable {
    /// The account workspace is loaded. Before it is, "no favourite" means
    /// "not read yet", and publishing it would blank every widget on the Home
    /// Screen for as long as a cold launch takes.
    let isAccountReady: Bool
    let places: [SavedPlace]
    let destinations: [SavedDestination]
    let lines: [LineStatus]
    let linesFetchedAt: Date?
}
