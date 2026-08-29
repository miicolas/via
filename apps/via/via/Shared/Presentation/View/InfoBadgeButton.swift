import SwiftUI

/// Square glass badge that carries one symbol and explains itself on tap.
///
/// The PMR badge and the habitual-affluence badge are both built on it, so the
/// two read as one family: same shape, same glass, same size — only the tint
/// and the symbol move with the degree they describe.
struct InfoBadgeButton: View {
    let symbol: String
    var variableValue: Double? = nil
    let tint: Color
    var size: CGFloat = 22
    /// `false` inside a row that is itself a button, where the row owns the tap.
    var isInteractive: Bool = true
    let title: String
    let message: String
    let accessibilityLabel: String
    var accessibilityValue: String = ""

    @State private var isExplaining = false

    var body: some View {
        if isInteractive {
            Button {
                isExplaining = true
            } label: {
                badge
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityValue(accessibilityValue)
            .accessibilityHint("Explique ce que signifie ce badge")
            .haptic(Haptic.commit, on: isExplaining) { !$0 && $1 }
            .popover(isPresented: $isExplaining) {
                InfoBadgeExplanationView(
                    symbol: symbol,
                    variableValue: variableValue,
                    tint: tint,
                    title: title,
                    message: message
                )
                .presentationCompactAdaptation(.popover)
            }
        } else {
            badge
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(accessibilityLabel)
                .accessibilityValue(accessibilityValue)
        }
    }

    private var badge: some View {
        GlassSquareBadge(tint: tint, size: size, isInteractive: true) {
            InfoBadgeSymbol(symbol: symbol, variableValue: variableValue)
                .font(.system(size: size * 0.54, weight: .bold))
        }
    }
}

/// The symbol as the badges draw it: full strength up to the degree reached, a
/// visible track underneath for the degree not reached. Without that track a
/// variable symbol at its lowest value reads as a half-drawn glyph instead of a
/// gauge with one bar lit.
struct InfoBadgeSymbol: View {
    let symbol: String
    var variableValue: Double?

    var body: some View {
        if let variableValue {
            ZStack {
                Image(systemName: symbol, variableValue: 1)
                    .foregroundStyle(.white.opacity(0.3))

                Image(systemName: symbol, variableValue: variableValue)
                    .foregroundStyle(.white)
            }
        } else {
            Image(systemName: symbol)
                .foregroundStyle(.white)
        }
    }
}

#Preview {
    HStack(spacing: 10) {
        InfoBadgeButton(
            symbol: "figure.roll",
            tint: .green,
            size: 24,
            title: "Accessibilité PMR",
            message: "Station praticable en fauteuil sans aide.",
            accessibilityLabel: "Accessibilité PMR",
            accessibilityValue: "En autonomie"
        )

        InfoBadgeButton(
            symbol: "cellularbars",
            variableValue: 0.9,
            tint: .red,
            size: 24,
            title: "Affluence habituelle",
            message: "Heure la plus chargée de la journée.",
            accessibilityLabel: "Affluence habituelle",
            accessibilityValue: "Châtelet, heure la plus chargée"
        )
    }
    .padding()
}
