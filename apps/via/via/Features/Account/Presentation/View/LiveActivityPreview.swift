import SwiftUI

struct LiveActivityPreview: View {
    var body: some View {
        VStack(spacing: 14) {
            HStack {
                LineBadgeView(route: previewRoute)
                Spacer()
                Text("EN TRAJET")
                    .font(.caption.bold())
                    .foregroundStyle(.green)
            }

            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Châtelet")
                        .font(.headline)
                    Text("Départ 10:15")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "arrow.right")
                    .foregroundStyle(.secondary)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Nation")
                        .font(.headline)
                    Text("Arrivée 10:29")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            ProgressView(value: 0.42)
                .tint(.green)
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [Color.indigo.opacity(0.88), Color.black.opacity(0.92)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: .rect(cornerRadius: 24)
        )
        .foregroundStyle(.white)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Aperçu d’une activité en direct pour un trajet entre Châtelet et Nation")
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
