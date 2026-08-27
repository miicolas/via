import SwiftUI
import WidgetKit

/// The favourite on the Lock Screen, where the system tints everything one
/// colour and the tile is barely bigger than a glyph.
struct FavoriteJourneyAccessoryView: View {
    let journey: WidgetFavoriteJourney
    let family: WidgetFamily

    var body: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: journey.systemImage)
                    .font(.title3)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Lancer le trajet \(journey.label)")

        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 1) {
                Label(journey.label, systemImage: journey.systemImage)
                    .font(.headline)
                    .lineLimit(1)

                Text(journey.destinationName)
                    .font(.caption)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Lancer le trajet \(journey.label)")
            .accessibilityValue("Vers \(journey.destinationName)")

        default:
            Label(journey.label, systemImage: journey.systemImage)
                .accessibilityLabel("Lancer le trajet \(journey.label)")
        }
    }
}
