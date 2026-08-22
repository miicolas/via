import SwiftUI

/// Via's square glass badge: the shape every badge that carries one mark on a
/// tinted square shares — the PMR and affluence badges, the numbered exit, the
/// boarding position.
///
/// The corner ratio, the glass and the white glyph live here so the family
/// cannot drift a badge at a time; only the tint, the size and the mark itself
/// are the caller's.
struct GlassSquareBadge<Content: View>: View {
    let tint: Color
    var size: CGFloat = 22
    /// `true` where the badge is itself the tap target.
    var isInteractive = false
    @ViewBuilder let content: () -> Content

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
    }

    var body: some View {
        content()
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(tint, in: shape)
            .glassEffect(isInteractive ? .regular.interactive() : .regular, in: shape)
            .contentShape(shape)
    }
}
