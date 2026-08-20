import SwiftUI

/// The shell every non-input state of the natural search sheet shares: the
/// Apple Intelligence badge, a title, then whatever that state has to say and
/// offer. Keeping it here stops the five state screens from drifting apart.
struct NaturalJourneyStateCard<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            AIBadge()
            Label(title, systemImage: systemImage)
                .font(.title2.weight(.bold))
            content
        }
        .padding(20)
    }
}

extension View {
    /// The explanatory paragraph under a state card title.
    func naturalJourneyMessage() -> some View {
        foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// The action a state card wants the traveller to take.
    func naturalJourneyPrimaryAction() -> some View {
        buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
    }

    /// The way out of a state card, always secondary to the action above it.
    func naturalJourneySecondaryAction() -> some View {
        buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
    }
}
