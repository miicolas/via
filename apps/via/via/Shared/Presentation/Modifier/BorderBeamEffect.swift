import SwiftUI

extension View {
    func borderBeam(
        border: Color,
        beam: [Color],
        beamBlur: CGFloat,
        cornerRadius: CGFloat,
        isEnabled: Bool,
    ) -> some View {
        borderBeam(
            border: border,
            beam: beam,
            beamBlur: beamBlur,
            shape: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous),
            isEnabled: isEnabled,
        )
    }

    func borderBeam<S: Shape>(
        border: Color,
        beam: [Color],
        beamBlur: CGFloat,
        shape: S,
        isEnabled: Bool,
    ) -> some View {
        modifier(BorderBeamEffect(
            border: border,
            beam: beam,
            beamBlur: beamBlur,
            shape: shape,
            isEnabled: isEnabled,
        ))
    }
}

struct BorderBeamEffect<S: Shape>: ViewModifier {
    let border: Color
    let beam: [Color]
    let beamBlur: CGFloat
    let shape: S
    let isEnabled: Bool

    func body(content: Content) -> some View {
        content.background {
            if isEnabled {
                KeyframeAnimator(initialValue: 0.0, repeating: true) { value in
                    let rotation = value * 360
                    let borderGradient = AngularGradient(
                        colors: [.clear, border, .clear],
                        center: .center,
                        startAngle: .degrees(140 + rotation),
                        endAngle: .degrees(270 + rotation),
                    )
                    let beamGradient = LinearGradient(
                        colors: beam,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing,
                    )

                    shape
                        .fill(beamGradient)
                        .mask {
                            Rectangle().overlay {
                                shape
                                    .blur(radius: beamBlur)
                                    .blendMode(.destinationOut)
                            }
                        }
                        .mask {
                            shape
                                .fill(borderGradient)
                                .blur(radius: beamBlur / 1.5)
                                .padding(-beamBlur * 2)
                        }
                        .overlay {
                            shape
                                .stroke(borderGradient, lineWidth: 0.8)
                        }
                } keyframes: { _ in
                    LinearKeyframe(1, duration: 2.5)
                }
                .padding(0.5)
                .accessibilityHidden(true)
            }
        }
    }
}
