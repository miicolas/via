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
}
