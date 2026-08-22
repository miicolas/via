import SwiftUI

/// Popover body of `InfoBadgeButton`: the badge again, at reading size, with
/// the sentence the symbol alone cannot say.
struct InfoBadgeExplanationView: View {
    let symbol: String
    var variableValue: Double?
    let tint: Color
    let title: String
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            InfoBadgeSymbol(symbol: symbol, variableValue: variableValue)
                .font(.headline.weight(.bold))
                .frame(width: 36, height: 36)
                .background(tint, in: shape)
                .glassEffect(.regular, in: shape)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(width: 280, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
    }
}

#Preview {
    InfoBadgeExplanationView(
        symbol: "cellularbars",
        variableValue: 0.9,
        tint: .red,
        title: "Affluence habituelle",
        message: "Châtelet : heure la plus chargée, quais denses.\n\nProfil habituel IDFM, pas du temps réel."
    )
}
