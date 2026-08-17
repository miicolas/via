import SwiftUI

extension View {
    /// The single look of every Via AI surface: the tinted card plus the animated border beam.
    func viaAISurface(
        cornerRadius: CGFloat = ViaAISurfaceStyle.cornerRadius
    ) -> some View {
        modifier(ViaAISurfaceStyle(cornerRadius: cornerRadius))
    }
}

/// Applies the shared Via AI card treatment. The beam is replaced by a static border
/// when Reduce Motion is enabled.
struct ViaAISurfaceStyle: ViewModifier {
    static let cornerRadius: CGFloat = 24
    static let border: Color = .white
    static let beam: [Color] = [.green, .blue, .pink, .orange, .indigo]
    static let beamBlur: CGFloat = 15

    var cornerRadius: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .borderBeam(
                border: Self.border,
                beam: Self.beam,
                beamBlur: Self.beamBlur,
                cornerRadius: cornerRadius,
                isEnabled: !reduceMotion
            )
            .background(
                Color.viaAISurface,
                in: RoundedRectangle(cornerRadius: cornerRadius)
            )
            .overlay {
                if reduceMotion {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .strokeBorder(Color.viaAIAccent.opacity(0.12), lineWidth: 1)
                }
            }
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    VStack(spacing: 16) {
        VStack(alignment: .leading, spacing: 12) {
            ViaAIBadge()
            Text("Prends le RER A puis la ligne 1 jusqu’à La Défense.")
                .font(.title3.weight(.medium))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .viaAISurface()

        Text("Rayon compact")
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .viaAISurface(cornerRadius: 18)
    }
    .padding()
}
