import SwiftUI

extension View {
    /// The action a screen wants the traveller to take. Full width, capsule,
    /// large: a prominent capsule that hugs its own label reads as a chip
    /// rather than as the thing to tap, and two of them stacked leave a ragged
    /// left column. `buttonSizing(.flexible)` is what actually stretches the
    /// glass — an outer `frame(maxWidth: .infinity)` only centres a hugging
    /// pill inside a wide frame.
    func primaryAction(tint: Color? = nil) -> some View {
        buttonStyle(.glassProminent)
            .buttonBorderShape(.capsule)
            .controlSize(.large)
            .buttonSizing(.flexible)
            .tint(tint)
    }

    /// The way out of a screen, always secondary to the action above it and
    /// exactly as wide, so the pair reads as one block instead of two chips.
    func secondaryAction() -> some View {
        buttonStyle(.glass)
            .buttonBorderShape(.capsule)
            .controlSize(.large)
            .buttonSizing(.flexible)
    }

    /// An action that rides along a row of content instead of standing on its
    /// own — a refresh next to a status line, a swap on a card. A round glyph
    /// is the only shrunken button Via allows; the label survives for VoiceOver.
    @ViewBuilder
    func iconAction(isProminent: Bool = false, size: ControlSize = .large) -> some View {
        // Only the button style branches — `.glass` and `.glassProminent` are
        // different types, so the shared chain is bound once around them.
        let base = labelStyle(.iconOnly)
            .buttonBorderShape(.circle)
            .controlSize(size)

        if isProminent {
            base.buttonStyle(.glassProminent)
        } else {
            base.buttonStyle(.glass)
        }
    }

    /// A sentence that happens to be tappable — the way an empty state points at
    /// a control that lives somewhere else on screen. It stays grey body text,
    /// the target's own symbol set inline in the sentence, because a capsule
    /// here would compete with the real action below it.
    func emptyStateHint() -> some View {
        font(.body)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
    }

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
