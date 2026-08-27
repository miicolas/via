import SwiftUI

/// The same favourite in one line, for the sizes that list several.
struct FavoriteJourneyShortcutView: View {
    let journey: WidgetFavoriteJourney

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: journey.systemImage)
                .font(.caption)
                .foregroundStyle(.tint)
                .frame(width: 22, height: 22)
                .background(.tint.opacity(0.15), in: .circle)

            VStack(alignment: .leading, spacing: 1) {
                Text(journey.label)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)

                Text(journey.destinationName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Lancer le trajet \(journey.label)")
        .accessibilityValue("Vers \(journey.destinationName)")
    }
}
