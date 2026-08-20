import SwiftUI

extension View {
    /// The light that sweeps across a label while Apple Intelligence works. It
    /// carries the "still going" signal a spinner would otherwise have to.
    func aiShimmer(isActive: Bool = true) -> some View {
        modifier(AIShimmerStyle(isActive: isActive))
    }
}

struct AIShimmerStyle: ViewModifier {
    let isActive: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @ViewBuilder
    func body(content: Content) -> some View {
        if isActive, !reduceMotion {
            TimelineView(.animation) { context in
                let cycle = 2.1
                let progress = context.date.timeIntervalSinceReferenceDate
                    .truncatingRemainder(dividingBy: cycle) / cycle
                // Starts and ends off-label so the band enters and leaves
                // instead of appearing in the middle of the word.
                let travel = progress * 2.2 - 0.6

                ZStack {
                    content.opacity(0.55)
                    content.mask {
                        LinearGradient(
                            colors: [.clear, .white, .clear],
                            startPoint: UnitPoint(x: travel - 0.4, y: 0.5),
                            endPoint: UnitPoint(x: travel + 0.4, y: 0.5),
                        )
                    }
                }
            }
        } else {
            content
        }
    }
}
