import SwiftUI

struct NaturalJourneyAvailabilityView: View {
    let guidance: NaturalJourneyUnavailableGuidance
    let onRetry: () -> Void
    let onClassicSearch: () -> Void

    var body: some View {
        NaturalJourneyStateCard(
            title: "Apple Intelligence indisponible",
            systemImage: "sparkles",
        ) {
            Text(guidance.message)
                .naturalJourneyMessage()
            Button("Réessayer", action: onRetry)
                .naturalJourneyPrimaryAction()
            Button("Recherche classique", action: onClassicSearch)
                .naturalJourneySecondaryAction()
        }
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
