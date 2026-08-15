import SwiftUI

struct ChatEmptyStateView: View {
    let onPrompt: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: "sparkles")
                .font(.title2)
                .foregroundStyle(ViaTheme.primary)

            Text("Parlez à Via")
                .font(ViaFont.title2)
                .foregroundStyle(ViaTheme.ink)

            Text("Demandez un itinéraire en langage naturel, avec votre position comme point de départ.")
                .font(ViaFont.subheadline)
                .foregroundStyle(ViaTheme.body)

            ViaButton("Aller à Châtelet", systemImage: "arrow.triangle.turn.up.right.diamond") {
                onPrompt("Comment aller à Châtelet ?")
            }
            .accessibilityIdentifier("via.chat.suggestion.chatelet")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(ViaTheme.accentSoft, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}
