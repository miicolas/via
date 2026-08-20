import SwiftUI

struct NaturalJourneyAvailabilityView: View {
    let guidance: NaturalJourneyUnavailableGuidance
    let onRetry: () -> Void
    let onClassicSearch: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            AIBadge()
            Label("Apple Intelligence indisponible", systemImage: "sparkles")
                .font(.title2.weight(.bold))
            Text(guidance.message)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button("Réessayer", action: onRetry)
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
            Button("Recherche classique", action: onClassicSearch)
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
        }
        .padding(20)
    }
}

private extension NaturalJourneyUnavailableGuidance {
    var message: String {
        switch self {
        case .enableAppleIntelligence:
            "Active Apple Intelligence dans Réglages > Apple Intelligence et Siri, puis reviens dans Via."
        case .modelDownloading:
            "Le modèle Apple Intelligence est encore en téléchargement. Réessaie lorsqu’il sera prêt."
        }
    }
}
