import SwiftUI

struct NaturalJourneyUnsupportedView: View {
    let message: String
    let suggestions: [String]
    let feedbackPhrase: String
    let onModify: () -> Void
    let onClassicSearch: () -> Void

    var body: some View {
        EmptyStateView(
            .ai(
                systemImage: "text.magnifyingglass",
                title: "Demande non reconnue",
                message: message,
            ),
        ) {
            if !suggestions.isEmpty {
                VStack(spacing: 8) {
                    ForEach(suggestions, id: \.self) { suggestion in
                        Text(suggestion)
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .glassEffect(.regular, in: .rect(cornerRadius: 18))
                    }
                }
            }
            NaturalJourneyRecoveryActions(onClassicSearch: onClassicSearch) {
                // Not a retry: editing the phrase opens the field rather than
                // redrawing this screen, so it takes no spin and no haptic.
                Button("Modifier la demande", systemImage: "pencil", action: onModify)
            }
            NaturalJourneyFeedbackShareLink(phrase: feedbackPhrase)
        }
    }
}
