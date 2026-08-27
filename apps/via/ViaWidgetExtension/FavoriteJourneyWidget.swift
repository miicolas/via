import SwiftUI
import WidgetKit

struct FavoriteJourneyWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: ViaWidgetKind.favoriteJourney,
            intent: SelectFavoriteJourneyIntent.self,
            provider: FavoriteJourneyProvider()
        ) { entry in
            FavoriteJourneyWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Trajet favori")
        .description("Lancez un trajet enregistré depuis l’écran d’accueil ou l’écran verrouillé.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline,
        ])
    }
}
