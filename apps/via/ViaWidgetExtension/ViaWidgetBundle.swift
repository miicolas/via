import SwiftUI
import WidgetKit

/// Everything Metyro puts outside the app: the two Home Screen and Lock Screen
/// widgets, and the three buttons for Control Centre and the Lock Screen.
///
/// The journey Live Activity keeps its own extension: it is driven by
/// ActivityKit while a trip runs, and shares neither its state nor its refresh
/// story with the favourites read from the App Group here.
@main
struct ViaWidgetBundle: WidgetBundle {
    var body: some Widget {
        FavoriteJourneyWidget()
        FavoriteLinesWidget()
        FavoriteJourneyControl()
        FavoriteLinesControl()
        SearchControl()
    }
}
