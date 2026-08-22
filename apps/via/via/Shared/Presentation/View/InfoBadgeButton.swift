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

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
    }

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
        Image(systemName: symbol, variableValue: variableValue)
            .font(.system(size: size * 0.54, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(tint, in: shape)
            .glassEffect(.regular.interactive(), in: shape)
            .contentShape(shape)
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
