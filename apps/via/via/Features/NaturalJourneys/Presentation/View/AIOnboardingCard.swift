import SwiftUI

struct AIOnboardingCard: View {
    let onTry: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 24) {
            hero

            VStack(spacing: 10) {
                Text("Décris simplement ton trajet")
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))
                    .multilineTextAlignment(.center)

                Text("Indique les lieux, l’heure et tes préférences dans une seule phrase.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text("« Je veux arriver à Châtelet demain avant 9 h »")
                .font(.body.weight(.medium))
                .multilineTextAlignment(.center)
                .padding(16)
                .frame(maxWidth: .infinity)
                .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 18))

            Label("La demande est traitée sur cet iPhone et n’est envoyée à aucun service d’IA externe.", systemImage: "lock.shield.fill")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button("Essayer", systemImage: "sparkles", action: onTry)
                .buttonStyle(AIBeamButtonStyle(isAnimated: true, reduceMotion: reduceMotion))
                .accessibilityHint("Ouvre le champ de recherche en langage naturel")
        }
        .padding(24)
        .frame(maxWidth: 520)
        .aiSurface(cornerRadius: 32)
        .padding(.horizontal, 16)
        .padding(.vertical, 20)
    }

    private var hero: some View {
        HStack(spacing: -12) {
            Image(systemName: "text.bubble.fill")
                .foregroundStyle(.blue)
                .frame(width: 62, height: 62)
                .background(.blue.opacity(0.16), in: Circle())

            Image(systemName: "sparkles")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 76, height: 76)
                .background(Color.aiAccent.gradient, in: Circle())
                .zIndex(1)

            Image(systemName: "tram.fill")
                .foregroundStyle(.green)
                .frame(width: 62, height: 62)
                .background(.green.opacity(0.16), in: Circle())
        }
        .accessibilityHidden(true)
    }
}
