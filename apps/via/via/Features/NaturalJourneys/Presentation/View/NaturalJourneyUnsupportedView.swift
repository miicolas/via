import SwiftUI

struct NaturalJourneyUnsupportedView: View {
    let message: String
    let suggestions: [String]
    let onModify: () -> Void
    let onClassicSearch: () -> Void

    var body: some View {
        NaturalJourneyStateCard(
            title: "Demande non reconnue",
            systemImage: "text.magnifyingglass"
        ) {
            Text(message)
                .naturalJourneyMessage()
            ForEach(suggestions, id: \.self) { suggestion in
                Text("• \(suggestion)")
                    .font(.subheadline)
            }
            NaturalJourneyRecoveryActions(
                primarySystemImage: "pencil",
                primaryLabel: "Modifier la demande",
                primaryAction: onModify,
                secondarySystemImage: "magnifyingglass",
                secondaryLabel: "Recherche classique",
                secondaryAction: onClassicSearch
            )
        }
    }
}
