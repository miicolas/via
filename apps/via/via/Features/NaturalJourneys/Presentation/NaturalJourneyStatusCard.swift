import SwiftUI

struct NaturalJourneyStatusCard: View {
    let title: String
    let systemImage: String
    let message: String
    let example: String?
    let onRetry: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ViaAIBadge()

            Label(title, systemImage: systemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)

            Text(message)
                .font(.body)
                .foregroundStyle(Color.viaAISecondary)
                .fixedSize(horizontal: false, vertical: true)

            if let example {
                Text(example)
                    .font(.footnote)
                    .foregroundStyle(Color.viaAISecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let onRetry {
                Button("Réessayer", systemImage: "arrow.clockwise", action: onRetry)
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .tint(Color.viaAIAccent)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .viaAISurface()
        .accessibilityElement(children: .contain)
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    NaturalJourneyStatusCard(
        title: "Recherche indisponible",
        systemImage: "wifi.exclamationmark",
        message: "Les horaires sont disponibles jusqu’au vendredi 7 août.",
        example: nil,
        onRetry: {}
    )
    .padding()
}
