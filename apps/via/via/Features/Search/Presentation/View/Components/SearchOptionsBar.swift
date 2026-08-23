import SwiftUI

struct SearchOptionsBar: View {
    let requestedAt: Date?
    let datetimeRepresents: JourneyDatetimeRepresents
    let requiresAccessibleStations: Bool
    let requiresOperationalElevators: Bool
    let onEditTime: () -> Void
    let onToggleAccessibleStations: () -> Void
    let onToggleOperationalElevators: () -> Void
    let onShowAccessibilityInfo: () -> Void

    var body: some View {
        GlassEffectContainer(spacing: 8) {
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    OptionChip(
                        title: timeTitle,
                        systemImage: "clock",
                        isActive: requestedAt != nil,
                        action: onEditTime,
                    )

                    OptionChip(
                        title: "PMR",
                        systemImage: "figure.roll",
                        isActive: requiresAccessibleStations,
                        action: onToggleAccessibleStations,
                    )
                    .accessibilityValue(requiresAccessibleStations ? "Activé" : "Désactivé")
                    .accessibilityHint("Active ou désactive la recherche de stations accessibles")
                    .contextMenu {
                        Button(
                            "À propos de l’accessibilité",
                            systemImage: "info.circle",
                            action: onShowAccessibilityInfo,
                        )
                    }

                    OptionChip(
                        title: "Ascenseurs",
                        systemImage: "arrow.up.arrow.down.square",
                        isActive: requiresOperationalElevators,
                        action: onToggleOperationalElevators,
                    )
                    .accessibilityValue(requiresOperationalElevators ? "Activé" : "Désactivé")
                    .accessibilityHint(
                        "N’affiche que les trajets dont tous les ascenseurs référencés sont disponibles"
                    )
                }
            }
            .scrollIndicators(.hidden)
        }
    }

    private var timeTitle: String {
        guard let requestedAt else { return "Maintenant" }
        return NaturalJourneyCriteria.timeLabel(requestedAt, represents: datetimeRepresents)
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 12) {
        SearchOptionsBar(
            requestedAt: nil,
            datetimeRepresents: .departure,
            requiresAccessibleStations: false,
            requiresOperationalElevators: false,
            onEditTime: {},
            onToggleAccessibleStations: {},
            onToggleOperationalElevators: {},
            onShowAccessibilityInfo: {},
        )

        SearchOptionsBar(
            requestedAt: .now,
            datetimeRepresents: .arrival,
            requiresAccessibleStations: true,
            requiresOperationalElevators: true,
            onEditTime: {},
            onToggleAccessibleStations: {},
            onToggleOperationalElevators: {},
            onShowAccessibilityInfo: {},
        )
    }
    .padding()
}
