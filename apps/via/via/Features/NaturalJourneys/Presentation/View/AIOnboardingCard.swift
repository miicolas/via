import SwiftUI

struct AIOnboardingCard: View {
    let onTry: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()

                Button("Fermer", systemImage: "xmark", action: onClose)
                    .iconAction()
                    .accessibilityHint("Ferme la recherche intelligente")
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)

            GeometryReader { geometry in
                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        hero
                        headline
                        example
                        privacy
                    }
                    .frame(maxWidth: 560)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 20)
                    .frame(minHeight: geometry.size.height, alignment: .center)
                    .frame(maxWidth: .infinity)
                }
                .scrollBounceBehavior(.basedOnSize)
            }

            Button(action: onTry) {
                Label {
                    Text("Commencer")
                } icon: {
                    Image(systemName: "arrow.right")
                }
            }
            .naturalJourneyPrimaryAction()
            .accessibilityHint("Ouvre le champ de recherche en langage naturel")
            .frame(maxWidth: 560)
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 14)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground).ignoresSafeArea())
    }

    private var hero: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.blue.opacity(0.16),
                            Color.aiAccent.opacity(0.2),
                            Color.pink.opacity(0.14),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing,
                    )
                )

            Circle()
                .fill(Color.aiAccent.opacity(0.16))
                .frame(width: 170, height: 170)
                .blur(radius: 42)

            ThinkingOrb(size: 138, period: 12)
        }
        .frame(height: 210)
        .overlay(alignment: .topLeading) {
            Label("Recherche intelligente", systemImage: "apple.intelligence")
                .font(.callout.weight(.semibold))
                .foregroundStyle(Color.aiAccent)
                .padding(20)
        }
    }

    private var headline: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Ton trajet, en une phrase")
                .font(.system(.largeTitle, design: .rounded).weight(.bold))
                .fixedSize(horizontal: false, vertical: true)

            Text("Indique où tu vas, quand tu veux arriver et ce qui compte pour toi. Via construit le trajet.")
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    private var example: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "quote.opening")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.aiAccent)
                .frame(width: 28, height: 28)
                .accessibilityHidden(true)

            Text("« Je veux arriver à Châtelet demain avant 9 h »")
                .font(.body.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(18)
        .background(Color.secondary.opacity(0.08), in: .rect(cornerRadius: 22))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Exemple : Je veux arriver à Châtelet demain avant 9 heures")
    }

    private var privacy: some View {
        Label {
            Text("Traitée sur cet iPhone quand c’est possible, sinon par le serveur sécurisé de Via. Le mode « Local uniquement » reste disponible dans Réglages.")
        } icon: {
            Image(systemName: "lock.shield.fill")
                .foregroundStyle(Color.aiAccent)
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
}

#Preview {
    AIOnboardingCard(onTry: {}, onClose: {})
}
