import SwiftUI

extension View {
    func borderBeam(
        border: Color,
        beam: [Color],
        beamBlur: CGFloat,
        cornerRadius: CGFloat,
        isEnabled: Bool,
    ) -> some View {
        modifier(BorderBeamEffect(
            border: border,
            beam: beam,
            beamBlur: beamBlur,
            cornerRadius: cornerRadius,
            isEnabled: isEnabled,
        ))
    }
}

struct BorderBeamEffect: ViewModifier {
    let border: Color
    let beam: [Color]
    let beamBlur: CGFloat
    let cornerRadius: CGFloat
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

                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(beamGradient)
                        .mask {
                            Rectangle().overlay {
                                RoundedRectangle(cornerRadius: cornerRadius)
                                    .blur(radius: beamBlur)
                                    .blendMode(.destinationOut)
                            }
                        }
                        .mask {
                            RoundedRectangle(cornerRadius: cornerRadius)
                                .fill(borderGradient)
                                .blur(radius: beamBlur / 1.5)
                                .padding(-beamBlur * 2)
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: cornerRadius)
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
