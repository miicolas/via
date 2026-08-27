import SwiftUI

/// Nothing to show is a designed tile, not a blank one.
///
/// The widget counterpart of the app's `EmptyStateView`: one glyph, one line,
/// and the sentence that names the way out. A widget has no button to offer,
/// so the way out is always "open the app and do this" — the whole tile is a
/// link to the screen where it can be done.
struct WidgetEmptyStateView: View {
    let systemImage: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(.secondary)

            Text(title)
                .font(.subheadline.weight(.semibold))
                .multilineTextAlignment(.center)

            Text(message)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(message)
    }
}

extension WidgetEmptyStateView {
    static let noFavoriteJourney = WidgetEmptyStateView(
        systemImage: "star",
        title: "Aucun trajet favori",
        message: "Enregistrez une destination dans Metyro pour la lancer d’ici."
    )

    static let noFavoriteLine = WidgetEmptyStateView(
        systemImage: "tram",
        title: "Aucune ligne suivie",
        message: "Ajoutez une ligne à vos favoris dans l’onglet Lignes."
    )
}
