import SwiftUI
import UIKit

struct NaturalJourneyUnavailableCard: View {
    let message: String
    let guidance: NaturalJourneyUnavailableGuidance?
    let onRetry: (() -> Void)?

    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ViaAIBadge()

            Label("Recherche indisponible", systemImage: "sparkles")
                .font(.title3.weight(.semibold))

            Text(message)
                .font(.body)
                .foregroundStyle(Color.viaAISecondary)
                .fixedSize(horizontal: false, vertical: true)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) { actions }
                VStack(alignment: .leading, spacing: 10) { actions }
            }
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .viaAISurface()
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var actions: some View {
        if guidance == .enableAppleIntelligence {
            Button("Ouvrir Réglages", systemImage: "gear") {
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                openURL(url)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .tint(Color.viaAIAccent)
        }

        if let onRetry {
            Button("Réessayer", systemImage: "arrow.clockwise", action: onRetry)
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
                .tint(Color.viaAIAccent)
        }
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    NaturalJourneyUnavailableCard(
        message: "Active Apple Intelligence pour continuer sans le serveur.",
        guidance: .enableAppleIntelligence,
        onRetry: {}
    )
    .padding()
}
