import SwiftUI

struct OnboardingDemoInputView: View {
    let query: String
    let onSend: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ViaAIBadge()

            VStack(alignment: .leading, spacing: 6) {
                Text("Décris ton trajet")
                    .font(.title2.weight(.semibold))

                Text("Via comprend les lieux, l’heure et ton intention.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(query)
                .font(.body)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 15)
                .background(
                    Color.secondary.opacity(0.12),
                    in: RoundedRectangle(cornerRadius: 18)
                )
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Requête d’exemple")
                .accessibilityValue(query)

            Button(action: onSend) {
                Label("Envoyer", systemImage: "arrow.up")
            }
            .buttonStyle(ViaAIBeamButtonStyle(reduceMotion: reduceMotion))
            .accessibilityIdentifier("onboarding-demo-send")

            Text("Appuie sur Envoyer pour voir comment Via trouve ton itinéraire.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .viaAISurface()
        .accessibilityElement(children: .contain)
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    OnboardingDemoInputView(
        query: OnboardingDemoFixture.query,
        onSend: {}
    )
    .padding()
}
