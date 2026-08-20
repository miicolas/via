import SwiftUI

struct NaturalJourneyUnsupportedView: View {
    let message: String
    let suggestions: [String]
    let onModify: () -> Void
    let onClassicSearch: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            AIBadge()
            Label("Demande non reconnue", systemImage: "text.magnifyingglass")
                .font(.title2.weight(.bold))
            Text(message)
                .foregroundStyle(.secondary)
            ForEach(suggestions, id: \.self) { suggestion in
                Text("• \(suggestion)")
                    .font(.subheadline)
            }
            Button("Modifier la demande", action: onModify)
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
            Button("Recherche classique", action: onClassicSearch)
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
        }
        .padding(20)
    }
}
