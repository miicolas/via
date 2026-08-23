import SwiftUI

@MainActor
struct SearchFiltersMenu: View {
    let filters: SearchFilters
    let onSetRequiresAccessibleStations: @MainActor (Bool) -> Void
    let onSetRequiresOperationalElevators: @MainActor (Bool) -> Void
    let onShowAccessibilityInfo: @MainActor () -> Void

    var body: some View {
        Menu {
            Toggle(
                isOn: Binding(
                    get: { filters.requiresAccessibleStations },
                    set: onSetRequiresAccessibleStations
                )
            ) {
                Label("PMR", systemImage: "figure.roll")
                    .labelStyle(.iconOnly)
            }
            .accessibilityLabel("PMR")

            Toggle(
                isOn: Binding(
                    get: { filters.requiresOperationalElevators },
                    set: onSetRequiresOperationalElevators
                )
            ) {
                Label("Ascenseurs", systemImage: "arrow.up.arrow.down.square")
                    .labelStyle(.iconOnly)
            }
            .accessibilityLabel("Ascenseurs opérationnels")

            Divider()

            Button("À propos de l’accessibilité", systemImage: "info.circle", action: onShowAccessibilityInfo)
        } label: {
            HStack(spacing: 4) {
                Image(
                    systemName: filters.activeCount > 0
                        ? "line.3.horizontal.decrease.circle.fill"
                        : "line.3.horizontal.decrease.circle"
                )

                if filters.activeCount > 0 {
                    Text("\(filters.activeCount)")
                        .font(.caption.weight(.bold))
                        .monospacedDigit()
                }
            }
        }
        .accessibilityLabel("Filtres de recherche")
        .accessibilityValue(
            filters.activeCount == 0
                ? "Aucun filtre actif"
                : "\(filters.activeCount) filtre\(filters.activeCount > 1 ? "s" : "") actif\(filters.activeCount > 1 ? "s" : "")"
        )
        .accessibilityHint("Affiche les filtres de recherche")
    }
}
