import SwiftUI

enum ViaSkeletonShape: Shape {
    case roundedRectangle(cornerRadius: CGFloat)
    case capsule
    case circle

    func path(in rect: CGRect) -> Path {
        switch self {
        case .roundedRectangle(let cornerRadius):
            RoundedRectangle(
                cornerRadius: min(cornerRadius, min(rect.width, rect.height) / 2),
                style: .continuous
            )
            .path(in: rect)
        case .capsule:
            Capsule().path(in: rect)
        case .circle:
            Circle().path(in: rect)
        }
    }
}

/// A quiet, adaptive placeholder inspired by the system's content placeholders.
/// The moving highlight is disabled automatically when Reduce Motion is enabled.
struct ViaSkeleton: View {
    let shape: ViaSkeletonShape

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @State private var shimmerPhase: CGFloat = 0

    init(_ shape: ViaSkeletonShape = .roundedRectangle(cornerRadius: 8)) {
        self.shape = shape
    }

    var body: some View {
        shape
            .fill(baseColor)
            .overlay {
                if !reduceMotion {
                    GeometryReader { proxy in
                        let beamWidth = max(72, proxy.size.width * 0.45)

                        LinearGradient(
                            colors: [
                                .clear,
                                highlightColor,
                                .clear,
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: beamWidth)
                        .frame(maxHeight: .infinity)
                        .offset(x: (shimmerPhase * 2 - 1) * proxy.size.width)
                    }
                    .mask { shape.fill(.white) }
                }
            }
            .onAppear {
                guard !reduceMotion else { return }
                shimmerPhase = 0
                withAnimation(.linear(duration: 1.25).repeatForever(autoreverses: false)) {
                    shimmerPhase = 1
                }
            }
            .onDisappear {
                shimmerPhase = 0
            }
            .accessibilityHidden(true)
    }

    private var baseColor: Color {
        colorScheme == .dark
            ? .white.opacity(0.13)
            : .black.opacity(0.07)
    }

    private var highlightColor: Color {
        colorScheme == .dark
            ? .white.opacity(0.18)
            : .white.opacity(0.58)
    }
}
