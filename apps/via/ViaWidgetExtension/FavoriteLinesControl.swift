import AppIntents
import SwiftUI
import WidgetKit

/// A Lock Screen and Control Centre button that opens the lines the traveller
/// follows.
///
/// A button, not a status readout: a control shows one glyph and cannot carry
/// the wording a disruption needs. The state belongs to `FavoriteLinesWidget`;
/// this is the way in.
struct FavoriteLinesControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: ViaWidgetKind.linesControl) {
            ControlWidgetButton(action: OpenViaRouteIntent(route: ViaWidgetLink.lines)) {
                Label("Lignes", systemImage: "tram.fill")
            }
        }
        .displayName("État des lignes")
        .description("Ouvre l’état des lignes que vous suivez.")
    }
}
