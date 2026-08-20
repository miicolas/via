import SwiftUI

/// The shell every non-input state of the natural search sheet shares: one
/// glyph, one title, one sentence, then whatever that state has to offer. The
/// column is centred because these screens are the whole sheet, not a card
/// pinned to its top edge — an error that hugs the top-left of a tall sheet
/// looks like a layout bug.
struct NaturalJourneyStateCard<Content: View>: View {
    let systemImage: String
    let title: String
    let message: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 22) {
            glyph

            VStack(spacing: 8) {
                Text(title)
                    .font(.system(.title2, design: .rounded).weight(.bold))
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 12) {
                content
            }
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
    }

    private var glyph: some View {
        Image(systemName: systemImage)
            .font(.system(size: 28, weight: .semibold))
            .foregroundStyle(Color.aiAccent)
            .frame(width: 72, height: 72)
            .glassEffect(.regular.tint(Color.aiSurface), in: .circle)
            .accessibilityHidden(true)
    }
}

extension View {
    /// The action a state card wants the traveller to take. Full width and
    /// labelled: these screens are dead ends until something is tapped, so the
    /// way out must never be a bare glyph. Only the tint is local — the shape
    /// is the one every action in Via uses.
    func naturalJourneyPrimaryAction() -> some View {
        primaryAction(tint: Color.aiAccent)
    }

    /// The way out of a state card, always secondary to the action above it.
    func naturalJourneySecondaryAction() -> some View {
        secondaryAction()
    }
}
