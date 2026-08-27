import SwiftUI

/// A static marketing preview of the two system surfaces. The real rendering
/// lives in the ActivityKit extension; this preview only explains what a live
/// journey looks like before the user starts one.
struct LiveActivityPreview: View {
    private enum Layout {
        /// Keep the compact preview at the same minimum width as the system
        /// Dynamic Island treatment shown in the product reference.
        static let dynamicIslandMinimumWidth: CGFloat = 330
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("APERÇU")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)

            lockScreenPreview
            dynamicIslandPreview
        }
        .padding(16)
        .background(.thinMaterial, in: .rect(cornerRadius: 24))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Aperçu des activités en direct de Metyro")
    }

    private var lockScreenPreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "tram.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.blue)
                    .accessibilityHidden(true)

                Text("Metyro")
                    .font(.caption.weight(.semibold))

                Spacer(minLength: 8)

                Text("EN TRAJET")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.green)
            }

            HStack(alignment: .top, spacing: 12) {
                LineBadgeView(route: previewRoute, size: 30)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Descendre dans 3 arrêts")
                        .font(.headline.weight(.semibold))
                        .lineLimit(1)

                    Text("Métro 1 · Direction Château de Vincennes")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.68))
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .trailing, spacing: 2) {
                    Text("Arrivée")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.68))
                    Text("10:29")
                        .font(.subheadline.weight(.bold).monospacedDigit())
                }
            }

            Capsule()
                .fill(.white.opacity(0.22))
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(Color.yellow)
                        .frame(width: 126)
                }
                .frame(height: 5)

            HStack(spacing: 6) {
                Image(systemName: "arrow.turn.down.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.68))
                    .accessibilityHidden(true)

                Text("Ensuite · Marcher jusqu’à Nation")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.68))
                    .lineLimit(1)
            }
        }
        .padding(16)
        .foregroundStyle(.white)
        .background(.black, in: .rect(cornerRadius: 20))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Écran verrouillé. Trajet en cours sur la ligne 1. Descendre dans 3 arrêts. Arrivée à 10 heures 29."
        )
    }

    private var dynamicIslandPreview: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("DYNAMIC ISLAND")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                LineBadgeView(route: previewRoute, size: 22)

                Text("Ligne 1")
                    .font(.caption.weight(.semibold))

                Spacer(minLength: 8)

                Image(systemName: "arrow.down.right")
                    .font(.caption2.weight(.bold))
                    .accessibilityHidden(true)

                Text("3")
                    .font(.caption.weight(.bold).monospacedDigit())
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 10)
            .frame(
                minWidth: Layout.dynamicIslandMinimumWidth,
                maxWidth: .infinity,
                alignment: .leading
            )
            .foregroundStyle(.white)
            .background(.black, in: Capsule())
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Dynamic Island. Ligne 1. Descendre dans 3 arrêts.")
        }
    }

    private var previewRoute: RouteBadge {
        RouteBadge(
            id: RouteID(rawValue: "settings-preview"),
            shortName: "1",
            mode: .metro,
            colorHex: "FFCD00",
            textColorHex: "000000"
        )
    }
}

#Preview("Activité en direct") {
    LiveActivityPreview()
        .padding()
}
