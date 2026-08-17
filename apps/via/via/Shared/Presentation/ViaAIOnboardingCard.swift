import SwiftUI

/// Onboarding pitch for natural-language journeys, shown wherever the sheet
/// has no history to display yet.
struct ViaAIOnboardingCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ViaAIBadge()

            Text("Demande ton trajet à Via")
                .font(.headline)

            Text("Écris par exemple « Gare du Nord à 11 h », puis touche Rechercher.")
                .font(.subheadline)
                .foregroundStyle(Color.viaAISecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .viaAISurface()
        .padding(.vertical, 16)
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    ViaAIOnboardingCard()
        .padding()
}
