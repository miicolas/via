import SwiftUI

extension EnvironmentValues {
    /// How long a subview should wait before playing its own entrance.
    ///
    /// `staggeredAppearance(rank:)` publishes the delay it applied, so a marker
    /// nested deep inside a row can arrive with that row without every view in
    /// between having to forward a parameter it does not care about.
    @Entry var appearanceDelay: Double = 0
}

extension View {
    /// Fades and lifts the view into place, delayed by its rank in a list.
    ///
    /// A timeline that reveals itself as one cascade reads as a route being
    /// traced; the same rows appearing at once read as a block that popped.
    /// Under Reduce Motion nothing moves and nothing is delayed.
    func staggeredAppearance(rank: Int, step: Double = 0.045, limit: Double = 0.5) -> some View {
        modifier(StaggeredAppearance(delay: min(Double(max(0, rank)) * step, limit)))
    }
}

private struct StaggeredAppearance: ViewModifier {
    let delay: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hasAppeared = false

    func body(content: Content) -> some View {
        content
            .opacity(hasAppeared ? 1 : 0)
            .offset(y: hasAppeared ? 0 : 16)
            .blur(radius: hasAppeared ? 0 : 2)
            .environment(\.appearanceDelay, reduceMotion ? 0 : delay)
            .onAppear {
                guard !hasAppeared else { return }

                guard !reduceMotion else {
                    hasAppeared = true
                    return
                }

                withAnimation(.smooth(duration: 0.5).delay(delay)) {
                    hasAppeared = true
                }
            }
    }
}

#Preview("Cascade") {
    @Previewable @State var generation = 0

    return VStack(spacing: 12) {
        VStack(spacing: 10) {
            ForEach(0..<6, id: \.self) { rank in
                HStack(spacing: 12) {
                    Circle()
                        .fill(.blue)
                        .frame(width: 26, height: 26)
                    Text("Étape \(rank + 1)")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .staggeredAppearance(rank: rank)
            }
        }
        .id(generation)

        Button("Rejouer") { generation += 1 }
    }
    .padding()
}
