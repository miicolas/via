import SwiftUI

/// The dot sphere Via turns while Apple Intelligence works. A spinner only says
/// "waiting"; a lattice of points folding through itself says "thinking", which
/// is what an on-device request actually is.
struct ThinkingOrb: View {
    var size: CGFloat = 96
    /// Seconds per full turn. Shorter reads as busier, not as faster.
    var period: Double = 7

    var body: some View {
        AIPaletteCanvas(size: size) { context, canvasSize, time in
            draw(&context, in: canvasSize, at: time)
        }
    }

    private func draw(
        _ context: inout GraphicsContext,
        in canvasSize: CGSize,
        at time: TimeInterval,
    ) {
        let radius = Double(min(canvasSize.width, canvasSize.height)) / 2
        let centerX = Double(canvasSize.width) / 2
        let centerY = Double(canvasSize.height) / 2

        let yaw = time * 2 * .pi / period
        // A slow nod keeps the poles from parking in one place, which is
        // what makes a rotating sphere read as a flat spinning disc.
        let tilt = sin(time * 0.6) * 0.34
        let breath = 1 + sin(time * 1.1) * 0.018
        let dotRadius = radius * 0.052

        for point in Self.lattice {
            let x = point.x * cos(yaw) + point.z * sin(yaw)
            let spun = point.z * cos(yaw) - point.x * sin(yaw)
            let y = point.y * cos(tilt) - spun * sin(tilt)
            // 0 at the far side of the sphere, 1 at the near side.
            let depth = (point.y * sin(tilt) + spun * cos(tilt) + 1) / 2

            let projection = radius * 0.88 * (0.84 + 0.16 * depth) * breath
            let dot = dotRadius * (0.4 + 0.6 * depth)
            let rect = CGRect(
                x: centerX + x * projection - dot,
                y: centerY + y * projection - dot,
                width: dot * 2,
                height: dot * 2,
            )

            context.fill(
                Path(ellipseIn: rect),
                with: .color(.white.opacity(0.12 + 0.88 * pow(depth, 1.5))),
            )
        }
    }

    /// A Fibonacci lattice: the cheap way to space points evenly on a sphere.
    /// A latitude/longitude grid clumps at the poles, and the clumps flicker
    /// as they turn.
    private static let lattice: [SIMD3<Double>] = {
        let count = 168
        let increment = Double.pi * (3 - 5.0.squareRoot())
        return (0 ..< count).map { index in
            let y = 1 - (Double(index) / Double(count - 1)) * 2
            let ring = (1 - y * y).squareRoot()
            let angle = increment * Double(index)
            return SIMD3(cos(angle) * ring, y, sin(angle) * ring)
        }
    }()
}

#Preview {
    VStack(spacing: 32) {
        ThinkingOrb(size: 120)
        ThinkingOrb(size: 44, period: 5)
    }
    .padding(40)
}
