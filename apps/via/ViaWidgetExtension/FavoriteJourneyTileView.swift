import SwiftUI

/// One favourite, drawn as the tile that fills a small widget and leads a
/// medium one.
struct FavoriteJourneyTileView: View {
    let journey: WidgetFavoriteJourney

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: journey.systemImage)
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 38, height: 38)
                .background(.tint.opacity(0.15), in: .rect(cornerRadius: 12, style: .continuous))

            Spacer(minLength: 0)

            Text(journey.label)
                .font(.headline)
                .lineLimit(1)

            Text(journey.destinationName)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Lancer le trajet \(journey.label)")
        .accessibilityValue("Vers \(journey.destinationName)")
    }
}
