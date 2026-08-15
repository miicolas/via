import SwiftUI

struct AuthView: View {
    let onContinueAnonymously: () -> Void

    var body: some View {
        UnavailableFeatureView(
            title: "Connexion",
            description: "Le service de compte n’est pas encore exposé par l’API Via. Vous pouvez utiliser la carte, les lignes et les trajets sans compte.",
            systemImage: "person.crop.circle.badge.exclamationmark",
            actionTitle: "Continuer sans compte",
            action: onContinueAnonymously
        )
        .accessibilityIdentifier("via.auth.unavailable")
    }
}
