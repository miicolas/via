import SwiftUI
import WidgetKit

struct FavoriteLinesWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: ViaWidgetKind.favoriteLines,
            intent: FavoriteLinesConfigurationIntent.self,
            provider: FavoriteLinesProvider()
        ) { entry in
            FavoriteLinesWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Lignes favorites")
        .description("L’état des lignes que vous suivez, sur l’écran d’accueil ou l’écran verrouillé.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .systemLarge,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline,
        ])
    }
}
