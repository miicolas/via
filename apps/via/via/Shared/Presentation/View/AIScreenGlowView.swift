import SwiftUI

/// The Apple Intelligence glow traced along the edges of the whole screen:
/// the same light as `aiBeam`, scaled up to frame the display while the
/// natural-language surface is open, and swelling while Metyro thinks.
struct AIScreenGlowView: View {
    var intensity: Intensity

    enum Intensity: Hashable {
        /// The surface is open: a quiet coloured edge.
        case ambient
        /// A request is in flight: the edge brightens and blooms inward.
        case thinking
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isRotating = false

    var body: some View {
        gradient
            .mask { edgeMask }
            .opacity(intensity == .thinking ? 1 : 0.45)
            .animation(.smooth(duration: 0.45), value: intensity)
            .accessibilityHidden(true)
    }

    /// One full-bleed gradient under a fixed mask. The only thing that moves
    /// is the gradient's rotation, driven by a single repeating Core Animation
    /// so the screen-sized layer never invalidates SwiftUI per frame.
    @ViewBuilder
    private var gradient: some View {
        if reduceMotion {
            LinearGradient(
                colors: Color.aiPalette,
                startPoint: .topLeading,
                endPoint: .bottomTrailing,
            )
        } else {
            GeometryReader { proxy in
                // A rotating square only covers every screen point when its
                // side is at least the screen diagonal — the inscribed circle
                // of the rotation must contain the far corners.
                let side = (proxy.size.width * proxy.size.width
                    + proxy.size.height * proxy.size.height).squareRoot() + 2
                AngularGradient(
                    colors: Color.aiPalette + [Color.aiPalette[0]],
                    center: .center,
                )
                .frame(width: side, height: side)
                .rotationEffect(.degrees(isRotating ? 360 : 0))
                .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
            }
            .onAppear {
                withAnimation(.linear(duration: 6).repeatForever(autoreverses: false)) {
                    isRotating = true
                }
            }
        }
    }

    /// A crisp rim plus an inward bloom, both hugging the display's own corner
    /// curve. Geometry only changes with `intensity`, never per frame.
    private var edgeMask: some View {
        let shape = ConcentricRectangle(corners: .concentric, isUniform: true)
        let isThinking = intensity == .thinking
        let rimWidth: CGFloat = isThinking ? 6 : 4
        let bloomWidth: CGFloat = isThinking ? 34 : 22

        return ZStack {
            shape
                .stroke(Color.white, lineWidth: rimWidth)
                .padding(rimWidth / 2)
                .blur(radius: isThinking ? 10 : 8)
            shape
                .stroke(Color.white.opacity(isThinking ? 0.7 : 0.4), lineWidth: bloomWidth)
                .padding(bloomWidth / 2)
                .blur(radius: isThinking ? 18 : 12)
        }
        // The Gaussian tail of the bloom reaches far past its radius; a soft
        // band cut here keeps the light on the edges instead of washing the
        // middle of the display.
        .mask {
            shape
                .stroke(Color.white, lineWidth: isThinking ? 90 : 60)
                .blur(radius: 24)
        }
    }
}

#Preview("Ambient") {
    Color.black
        .ignoresSafeArea()
        .overlay { AIScreenGlowView(intensity: .ambient).ignoresSafeArea() }
}

#Preview("Thinking") {
    Color.black
        .ignoresSafeArea()
        .overlay { AIScreenGlowView(intensity: .thinking).ignoresSafeArea() }
}
