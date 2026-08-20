import SwiftUI

struct NaturalJourneyUnsupportedView: View {
    let message: String
    let suggestions: [String]
    let onModify: () -> Void
    let onClassicSearch: () -> Void

    var body: some View {
        NaturalJourneyStateCard(
            title: "Demande non reconnue",
            systemImage: "text.magnifyingglass",
        ) {
            Text(message)
                .naturalJourneyMessage()
            ForEach(suggestions, id: \.self) { suggestion in
                Text("• \(suggestion)")
                    .font(.subheadline)
            }
            Button("Modifier la demande", action: onModify)
                .naturalJourneyPrimaryAction()
            Button("Recherche classique", action: onClassicSearch)
                .naturalJourneySecondaryAction()
        }
    }
}
