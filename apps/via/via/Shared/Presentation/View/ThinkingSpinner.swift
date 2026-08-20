import SwiftUI

/// The dotted ring that turns beside the label. Dots rather than an arc so the
/// spinner belongs to the same family as ``ThinkingOrb``, and a fading tail
/// rather than a uniform ring so the direction of travel is readable at 16 pt.
struct ThinkingSpinner: View {
    var size: CGFloat = 16
    /// Seconds per full turn.
    var period: Double = 1.7

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
        let orbit = radius * 0.78
        let dotRadius = radius * 0.16

        let count = 12
        let spin = time * 2 * .pi / period

        for index in 0 ..< count {
            // 0 at the tail of the comet, 1 at its head.
            let position = Double(index) / Double(count)
            let angle = spin + position * 2 * .pi
            let dot = dotRadius * (0.42 + 0.58 * position)
            let rect = CGRect(
                x: centerX + cos(angle) * orbit - dot,
                y: centerY + sin(angle) * orbit - dot,
                width: dot * 2,
                height: dot * 2,
            )

            context.fill(
                Path(ellipseIn: rect),
                with: .color(.white.opacity(0.16 + 0.84 * pow(position, 1.4))),
            )
        }
    }
}

#Preview {
    HStack(spacing: 20) {
        ThinkingSpinner(size: 16)
        ThinkingSpinner(size: 44)
    }
    .padding(40)
}
