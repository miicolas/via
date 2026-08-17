import SwiftUI

struct ViaAIBeamButtonStyle: ButtonStyle {
    let reduceMotion: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .contentShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .borderBeam(
                border: ViaAISurfaceStyle.border,
                beam: ViaAISurfaceStyle.beam,
                beamBlur: ViaAISurfaceStyle.beamBlur,
                cornerRadius: 999,
                isEnabled: !reduceMotion
            )
            .background(Color.viaAIAccent, in: Capsule())
            .overlay {
                if reduceMotion {
                    Capsule()
                        .strokeBorder(.white.opacity(0.45), lineWidth: 1)
                }
            }
            .animation(
                reduceMotion ? nil : .easeOut(duration: 0.15),
                value: configuration.isPressed
            )
    }
}
