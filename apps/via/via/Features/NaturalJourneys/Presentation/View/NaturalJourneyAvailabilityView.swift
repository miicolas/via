import SwiftUI

struct NaturalJourneyAvailabilityView: View {
    let guidance: NaturalJourneyUnavailableGuidance
    let onRetry: () -> Void
    let onClassicSearch: () -> Void

    var body: some View {
        EmptyStateView(
            .ai(
                systemImage: "apple.intelligence.badge.xmark",
                title: guidance.title,
                message: guidance.message,
            ),
        ) {
            // The steps stay left-aligned inside a centred column: a checklist
            // read as a paragraph of centred lines is a checklist nobody reads.
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
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .glassEffect(.regular, in: .rect(cornerRadius: 22))

            NaturalJourneyRecoveryActions(onClassicSearch: onClassicSearch) {
                RetryButton(action: onRetry)
            }
        }
    }
}
