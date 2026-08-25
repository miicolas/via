import SwiftUI

struct AppleIntelligenceSettingsView: View {
    let searchViewModel: SearchViewModel

    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(NaturalJourneyProcessingPreference.serverFallbackKey)
    private var serverFallbackEnabled = true

    var body: some View {
        List {
            Section {
                Label(status, systemImage: statusImage)
                    .foregroundStyle(statusColor)

                Text(message)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } header: {
                Label("Recherche naturelle", systemImage: "apple.intelligence")
            }

            Section {
                LabeledContent {
                    Toggle(isOn: $serverFallbackEnabled) {
                        Label(
                            "Autoriser le serveur sécurisé",
                            systemImage: "lock.shield.fill",
                        )
                    }
                    .labelStyle(.iconOnly)
                    .accessibilityLabel("Autoriser le serveur sécurisé")
                    .accessibilityValue(serverFallbackEnabled ? "Activé" : "Désactivé")
                } label: {
                    Label("Serveur sécurisé", systemImage: "lock.shield.fill")
                }
            } header: {
                Text("Traitement")
            } footer: {
                Text(serverFallbackEnabled
                    ? "Si le traitement local ne peut pas terminer la compréhension, la phrase est envoyée au serveur sécurisé de Via. Elle n’est pas conservée."
                    : "Mode local uniquement. Les formulations déterministes restent disponibles, mais certaines demandes complexes peuvent nécessiter une saisie classique.")
            }

            if let guidance {
                Section("SUR CET IPHONE") {
                    ForEach(Array(guidance.instructions.enumerated()), id: \.offset) {
                        _, instruction in
                        Label(instruction.text, systemImage: instruction.systemImage)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            Section("CONFIDENTIALITÉ") {
                Label("Aucun historique de phrases", systemImage: "text.badge.xmark")
                Label("Les adresses enregistrées restent sur cet iPhone", systemImage: "mappin.slash")
                Label("Retour détaillé uniquement avec ton accord", systemImage: "checkmark.shield.fill")
            }
        }
        .navigationTitle("Recherche intelligente")
        .navigationBarTitleDisplayMode(.inline)
        .id(scenePhase)
    }

    private var status: String {
        switch searchViewModel.naturalLanguageAccess {
        case .active: serverFallbackEnabled ? "Local quand possible" : "Local uniquement"
        case .explanation(.enableAppleIntelligence): "À activer"
        case .explanation(.modelNotReady): "Modèle en préparation"
        case .explanation(.systemUnavailable): "Temporairement indisponible"
        case .hidden: "Non pris en charge"
        }
    }

    private var message: String {
        switch searchViewModel.naturalLanguageAccess {
        case .active:
            serverFallbackEnabled
                ? "Décris ton trajet avec tes propres mots. Il est traité sur cet iPhone quand c’est possible, sinon par le serveur sécurisé de Via."
                : "Décris ton trajet avec tes propres mots. Aucun modèle serveur ne sera utilisé."
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
