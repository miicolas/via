import SwiftUI

struct AIOnboardingCard: View {
    let onTry: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            ThinkingOrb(size: 104, period: 10)
                .background {
                    Circle()
                        .fill(Color.aiAccent.opacity(0.12))
                        .frame(width: 136, height: 136)
                        .blur(radius: 42)
                }

            VStack(spacing: 10) {
                Text("Décris simplement ton trajet")
                    .font(.system(.title2, design: .rounded).weight(.bold))
                Text("Les lieux, l’heure et tes préférences dans une seule phrase.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)

            Text("« Je veux arriver à Châtelet demain avant 9 h »")
                .font(.callout.weight(.medium))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .glassEffect(.regular.tint(Color.aiSurface), in: .rect(cornerRadius: 20))

            Button("Essayer", systemImage: "arrow.right", action: onTry)
                .naturalJourneyPrimaryAction()
                .accessibilityHint("Ouvre le champ de recherche en langage naturel")

            Label(
                "La demande est traitée sur cet iPhone et n’est envoyée à aucun service d’IA externe.",
                systemImage: "lock.shield.fill",
            )
            .font(.footnote)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
    }
}
