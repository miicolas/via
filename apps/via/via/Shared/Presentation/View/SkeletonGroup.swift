import SwiftUI

extension View {
    /// Marks a block of `Skeleton` shapes as one loading unit: a single sweeping
    /// highlight for the whole block, and a single VoiceOver element.
    func skeletonGroup(label: String) -> some View {
        modifier(SkeletonGroup(label: label))
    }
}

/// The highlight sweeps the group rather than each bar, so a screen full of
/// placeholders costs one animation — and stays visible on bars too thin to
/// carry a gradient of their own.
struct SkeletonGroup: ViewModifier {
    let label: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .compositingGroup()
            .overlay { highlight }
            .compositingGroup()
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(label)
            .accessibilityAddTraits(.updatesFrequently)
    }

    @ViewBuilder
    private var highlight: some View {
        if !reduceMotion {
            GeometryReader { proxy in
                let beamWidth = max(96, proxy.size.width * 0.4)

                LinearGradient(
                    colors: [.clear, .white.opacity(0.45), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: beamWidth)
                .frame(maxHeight: .infinity)
                .offset(x: phase * (proxy.size.width + beamWidth) - beamWidth)
            }
            // Paints only where the group already drew something, so the beam
            // rides the placeholder shapes without needing a duplicate mask.
            .blendMode(.sourceAtop)
            .allowsHitTesting(false)
            .onAppear {
                phase = 0
                withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
            .onDisappear { phase = 0 }
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 14) {
        Skeleton(.capsule)
            .frame(width: 180, height: 14)

        Skeleton(.capsule)
            .frame(width: 240, height: 12)

        Skeleton(.capsule)
            .frame(width: 120, height: 12)
    }
    .padding()
    .skeletonGroup(label: "Chargement…")
}
