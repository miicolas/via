import Foundation

/// The kind strings WidgetKit and Control Centre store against a placed
/// widget. Named once: changing one after release orphans every widget the
/// traveller already put on a screen.
enum ViaWidgetKind {
    static let favoriteJourney = "dev.via.app.widget.favorite-journey"
    static let favoriteLines = "dev.via.app.widget.favorite-lines"
    static let favoriteJourneyControl = "dev.via.app.control.favorite-journey"
    static let linesControl = "dev.via.app.control.lines"
    static let searchControl = "dev.via.app.control.search"
}
