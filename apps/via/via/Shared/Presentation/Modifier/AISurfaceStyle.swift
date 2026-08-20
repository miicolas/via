import SwiftUI

extension Color {
    static let aiAccent = Color.purple
    static let aiSurface = Color.purple.opacity(0.08)
}

extension View {
    func aiSurface(cornerRadius: CGFloat = 24) -> some View {
        modifier(AISurfaceStyle(cornerRadius: cornerRadius))
    }
}

struct AISurfaceStyle: ViewModifier {
    let cornerRadius: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .borderBeam(
                border: .white,
                beam: [.purple, .blue, .pink, .indigo],
                beamBlur: 15,
                cornerRadius: cornerRadius,
                isEnabled: !reduceMotion,
            )
            .background(
                Color.aiSurface,
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

struct AIBeamButtonStyle: ButtonStyle {
    let isAnimated: Bool
    let reduceMotion: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 52)
            .contentShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .borderBeam(
                border: .white,
                beam: [.purple, .blue, .pink, .indigo],
                beamBlur: 15,
                cornerRadius: 999,
                isEnabled: isAnimated && !reduceMotion,
            )
            .background(Color.aiAccent, in: Capsule())
            .animation(
                reduceMotion ? nil : .easeOut(duration: 0.15),
                value: configuration.isPressed,
            )
    }
}
