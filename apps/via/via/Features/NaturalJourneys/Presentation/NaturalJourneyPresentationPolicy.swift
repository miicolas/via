enum NaturalJourneyPresentationPolicy {
    static let entryAccessibilityLabel = "Rechercher avec Apple Intelligence"
    static let entryAccessibilityHint = "Décris ton trajet dans une phrase"

    static func expandsForInput(_ state: NaturalSearchState) -> Bool {
        state == .input
    }

    /// Every state is one short column the sheet centres, except the one the
    /// traveller types into: a field that drifts down the sheet and then jumps
    /// when the keyboard arrives reads as broken. Defined as the negation of
    /// `expandsForInput` so the two can never be edited apart.
    static func centersContent(_ state: NaturalSearchState) -> Bool {
        !expandsForInput(state)
    }

    /// Which states have an answer or a question to show: the conversational
    /// panel in the composer, and the raised sheet detent that hosts it. One
    /// predicate for both so the detent and the panel can never disagree.
    static func showsPanel(_ state: NaturalSearchState) -> Bool {
        switch state {
        case .dismissed, .input, .loading:
            false
        case .onboarding, .clarification, .decision, .unsupported, .availability, .failed:
            true
        }
    }
}

struct NaturalJourneyRecoveryInstruction: Sendable, Hashable {
    let systemImage: String
    let text: String
}

extension NaturalJourneyUnavailableGuidance {
    var title: String {
        switch self {
        case .enableAppleIntelligence:
            "Active Apple Intelligence"
        case .modelNotReady:
            "Apple Intelligence se prépare"
        case .systemUnavailable:
            "Apple Intelligence ne répond pas"
        }
    }

    var message: String {
        switch self {
        case .enableAppleIntelligence:
            "Via a besoin d’Apple Intelligence pour comprendre cette demande de trajet en mode local."
        case .modelNotReady:
            "Le modèle n’est pas encore prêt. iOS peut encore le télécharger ou le préparer."
        case .systemUnavailable:
            "Le modèle est activé, mais iOS n’a pas pu terminer cette demande. Ta phrase n’est pas en cause."
        }
    }

    var instructions: [NaturalJourneyRecoveryInstruction] {
        switch self {
        case .enableAppleIntelligence:
            [
                .init(
                    systemImage: "gearshape",
                    text: "Ouvre Réglages > Apple Intelligence et Siri.",
                ),
                .init(
                    systemImage: "checkmark.circle",
                    text: "Active Apple Intelligence, puis reviens dans Via.",
                ),
            ]
        case .modelNotReady:
            [
                .init(
                    systemImage: "wifi",
                    text: "Connecte l’iPhone au Wi-Fi.",
                ),
                .init(
                    systemImage: "powerplug.fill",
                    text: "Branche-le à l’alimentation et laisse le modèle se préparer.",
                ),
                .init(
                    systemImage: "internaldrive",
                    text: "Vérifie que l’iPhone dispose des 7 Go de stockage requis par Apple Intelligence.",
                ),
                .init(
                    systemImage: "character.bubble",
                    text: "La langue de l’iPhone et celle de Siri doivent être identiques et prises en charge.",
                ),
            ]
        case .systemUnavailable:
            [
                .init(
                    systemImage: "arrow.down.circle",
                    text: "Installe la dernière version d’iOS.",
                ),
                .init(
                    systemImage: "gearshape",
                    text: "Vérifie qu’Apple Intelligence est activée dans Réglages > Apple Intelligence et Siri.",
                ),
                .init(
                    systemImage: "wifi",
                    text: "Garde l’iPhone connecté au Wi-Fi et à l’alimentation pendant la préparation des modèles.",
                ),
            ]
        }
    }
}
