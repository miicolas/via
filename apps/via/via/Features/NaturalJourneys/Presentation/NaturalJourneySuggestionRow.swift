import SwiftUI

struct NaturalJourneySuggestionRow: View {
    let query: String
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.headline)
                    .foregroundStyle(Color.viaAIAccent)
                    .frame(width: 38, height: 38)
                    .background(.background.opacity(0.7), in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text("Demander à Via")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.viaAIAccent)

                    Text("Interpréter « \(query) » comme un trajet")
                        .font(.subheadline)
                        .foregroundStyle(Color.viaAISecondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 8)

                Image(systemName: "arrow.up.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.viaAIAccent)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .viaAISurface(cornerRadius: 18)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Demander à Via : \(query)")
        .accessibilityHint("Interprète cette phrase et recherche des itinéraires")
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    NaturalJourneySuggestionRow(query: "Chatou à 14 h", onSelect: {})
        .padding()
}
