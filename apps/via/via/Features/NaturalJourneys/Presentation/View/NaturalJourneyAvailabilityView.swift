import SwiftUI

struct NaturalJourneyAvailabilityView: View {
    let guidance: NaturalJourneyUnavailableGuidance
    let onRetry: () -> Void
    let onClassicSearch: () -> Void

    var body: some View {
        NaturalJourneyStateCard(
            title: guidance.title,
            systemImage: "apple.intelligence.badge.xmark"
        ) {
            Text(guidance.message)
                .naturalJourneyMessage()
            VStack(alignment: .leading, spacing: 14) {
                ForEach(Array(guidance.instructions.enumerated()), id: \.offset) { _, instruction in
                    Label {
                        Text(instruction.text)
                            .fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        Image(systemName: instruction.systemImage)
                            .foregroundStyle(Color.aiAccent)
                    }
                }
            }
            .font(.subheadline)
            NaturalJourneyRecoveryActions(
                primarySystemImage: "arrow.clockwise",
                primaryLabel: "Réessayer",
                primaryAction: onRetry,
                secondarySystemImage: "magnifyingglass",
                secondaryLabel: "Recherche classique",
                secondaryAction: onClassicSearch
            )
        }
    }
}
