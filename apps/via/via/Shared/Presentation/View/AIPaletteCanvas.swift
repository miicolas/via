import SwiftUI

/// The renderer behind every Apple Intelligence dot field in Via. The field is
/// drawn in white and used as a mask, so the palette shades it as a whole
/// instead of every dot carrying its own colour.
///
/// Reduce-motion, the display-link redraw and the accessibility handling live
/// here rather than in each field, so the AI motion contract is one decision:
/// a caller supplies only the geometry it draws.
struct AIPaletteCanvas: View {
    let size: CGFloat
    let draw: (inout GraphicsContext, CGSize, TimeInterval) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        LinearGradient(
            colors: Color.aiPalette,
            startPoint: .topLeading,
            endPoint: .bottomTrailing,
        )
        .mask {
            if reduceMotion {
                field(at: 0)
            } else {
                TimelineView(.animation) { context in
                    field(at: context.date.timeIntervalSinceReferenceDate)
                }
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private func field(at time: TimeInterval) -> some View {
        Canvas { context, canvasSize in
            draw(&context, canvasSize, time)
        }
    }
}
