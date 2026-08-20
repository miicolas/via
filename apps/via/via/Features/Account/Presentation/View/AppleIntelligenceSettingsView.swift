import SwiftUI

struct AppleIntelligenceSettingsView: View {
    let searchViewModel: SearchViewModel

    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Image(systemName: "sparkles")
                    .font(.system(size: 46, weight: .semibold))
                    .foregroundStyle(.purple)

                Text("Recherche naturelle")
                    .font(.largeTitle.bold())

                Text(message)
                    .font(.title3)
                    .foregroundStyle(.secondary)

                Label(status, systemImage: statusImage)
                    .font(.headline)
                    .foregroundStyle(statusColor)
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.quaternary, in: .rect(cornerRadius: 20))

                if let guidance {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(Array(guidance.instructions.enumerated()), id: \.offset) {
                            _, instruction in
                            Label(instruction.text, systemImage: instruction.systemImage)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .font(.body)
                }
            }
            .padding(24)
        }
        .navigationTitle("Apple Intelligence")
        .navigationBarTitleDisplayMode(.inline)
        .id(scenePhase)
    }

    private var status: String {
        switch searchViewModel.naturalLanguageAccess {
        case .active: "Disponible"
        case .explanation(.enableAppleIntelligence): "À activer"
        case .explanation(.modelNotReady): "Modèle en préparation"
        case .explanation(.systemUnavailable): "Temporairement indisponible"
        case .hidden: "Non pris en charge"
        }
    }

    private var message: String {
        switch searchViewModel.naturalLanguageAccess {
        case .active:
            "Décris ton trajet avec tes propres mots. Le traitement reste sur l’appareil."
        case .explanation(.enableAppleIntelligence):
            "Active Apple Intelligence dans Réglages > Apple Intelligence et Siri, puis reviens dans Via."
        case .explanation(.modelNotReady):
            "Le modèle n’est pas encore prêt. Garde l’appareil connecté au Wi-Fi et à l’alimentation."
        case .explanation(.systemUnavailable):
            "Apple Intelligence a rencontré un problème système. Vérifie iOS et les réglages Apple Intelligence, puis réessaie."
        case .hidden:
            "Cet appareil ou cette langue ne permet pas encore d’utiliser la recherche naturelle."
        }
    }

    private var statusImage: String {
        searchViewModel.naturalLanguageAccess == .active ? "checkmark.circle.fill" : "info.circle.fill"
    }

    private var statusColor: Color {
        searchViewModel.naturalLanguageAccess == .active ? .green : .orange
    }

    private var guidance: NaturalJourneyUnavailableGuidance? {
        guard case let .explanation(guidance) = searchViewModel.naturalLanguageAccess else {
            return nil
        }
        return guidance
    }
}
