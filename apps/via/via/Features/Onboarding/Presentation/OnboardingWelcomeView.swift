import SwiftUI

struct OnboardingWelcomeView: View {
    let onStart: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ViaAIBadge()

            VStack(alignment: .leading, spacing: 8) {
                Text("Bienvenue dans Via")
                    .font(.largeTitle.weight(.bold))
                    .fixedSize(horizontal: false, vertical: true)

                Text("Demande ton trajet avec des mots simples. Via comprend ta destination et l’heure à laquelle tu veux arriver.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Label(
                "Un exemple guidé, en quelques secondes",
                systemImage: "sparkles"
            )
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color.viaAIAccent)

            Button("Commencer", action: onStart)
                .buttonStyle(ViaAIBeamButtonStyle(reduceMotion: reduceMotion))
                .accessibilityIdentifier("onboarding-start")
                .accessibilityHint("Lance la démonstration de recherche de trajet")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .viaAISurface()
        .accessibilityElement(children: .contain)
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    OnboardingWelcomeView(onStart: {})
        .padding()
}
