import SwiftUI

struct NaturalJourneyLoadingView: View {
    let phrase: String

    var body: some View {
        VStack(spacing: 16) {
            ThinkingPill()

            if !phrase.isEmpty {
                Text("« \(phrase) »")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Metyro comprend ta demande : \(phrase)")
        .accessibilityAddTraits(.updatesFrequently)
    }
}

#Preview {
    NaturalJourneyLoadingView(phrase: "Je veux arriver à Châtelet demain avant 9 h")
        .padding(24)
}
