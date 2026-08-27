import AppIntents
import SwiftUI
import WidgetKit

/// A Lock Screen and Control Centre button that opens Metyro ready for a
/// destination — the shortcut for the journey that is not a favourite.
struct SearchControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: ViaWidgetKind.searchControl) {
            ControlWidgetButton(action: OpenViaRouteIntent(route: ViaWidgetLink.search)) {
                Label("Itinéraire", systemImage: "magnifyingglass")
            }
        }
        .displayName("Nouvel itinéraire")
        .description("Ouvre Metyro sur la recherche d’itinéraire.")
    }
}
