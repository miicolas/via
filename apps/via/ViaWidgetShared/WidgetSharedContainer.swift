import Foundation

/// The App Group the app and the widget extension share.
///
/// Widgets run in their own process and cannot read `UserDefaults.standard` of
/// the app, so anything a tile draws has to cross this container. The app is
/// the only writer of the favourites snapshot and the extension the only
/// writer of the pending route: two one-way channels rather than a shared
/// mutable store, which is what keeps the two processes from racing.
enum WidgetSharedContainer {
    /// Mirrors the app's own identifier prefix. The brand is Metyro, the
    /// identifiers never moved — same rule as `APIClientKey.header`.
    static let appGroupIdentifier = "group.dev.via.app"

    /// `nil` when the running build has no App Group entitlement. Every caller
    /// treats that as "no shared state yet" rather than a failure: a widget
    /// then draws its empty state instead of crashing the extension.
    static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupIdentifier)
    }
}
