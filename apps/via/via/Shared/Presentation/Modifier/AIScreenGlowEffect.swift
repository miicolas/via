import SwiftUI

extension View {
    /// Frames the whole screen with the Apple Intelligence glow. `nil` removes
    /// it; the edge fades in and out rather than popping, and never intercepts
    /// touches.
    func aiScreenGlow(_ intensity: AIScreenGlowView.Intensity?) -> some View {
        modifier(AIScreenGlowEffect(intensity: intensity))
    }
}

struct AIScreenGlowEffect: ViewModifier {
    let intensity: AIScreenGlowView.Intensity?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.overlay {
            ZStack {
                if let intensity {
                    AIScreenGlowView(intensity: intensity)
                        .transition(.opacity)
                }
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .animation(reduceMotion ? nil : .smooth(duration: 0.45), value: intensity)
        }
    }
}
