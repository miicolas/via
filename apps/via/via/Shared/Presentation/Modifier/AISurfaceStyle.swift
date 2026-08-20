import SwiftUI

extension Color {
    static let aiAccent = Color.purple
    static let aiSurface = Color.purple.opacity(0.08)
}

extension View {
    func aiSurface(cornerRadius: CGFloat = 24) -> some View {
        modifier(AISurfaceStyle(cornerRadius: cornerRadius))
    }

    /// The Apple Intelligence beam, defined once so every AI surface in the app
    /// animates with the same palette.
    func aiBeam(cornerRadius: CGFloat, blur: CGFloat = 15, isEnabled: Bool) -> some View {
        aiBeam(
            in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous),
            blur: blur,
            isEnabled: isEnabled,
        )
    }

    /// The same beam traced along an arbitrary shape, so round controls keep a
    /// round halo instead of the rounded rectangle the corner-radius form draws.
    func aiBeam(in shape: some Shape, blur: CGFloat = 15, isEnabled: Bool) -> some View {
        borderBeam(
            border: .white,
            beam: [.purple, .blue, .pink, .indigo],
            beamBlur: blur,
            shape: shape,
            isEnabled: isEnabled,
        )
    }
}

struct AISurfaceStyle: ViewModifier {
    let cornerRadius: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .aiBeam(cornerRadius: cornerRadius, isEnabled: !reduceMotion)
            // Glass with a whisper of the accent: a flat purple fill this large
            // reads as a purple card rather than as an AI surface.
            .glassEffect(
                .regular.tint(Color.aiSurface),
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous),
            )
            .overlay {
                if reduceMotion {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(Color.aiAccent.opacity(0.2), lineWidth: 1)
                }
            }
    }
}
