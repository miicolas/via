import SwiftUI

/// Retry, everywhere Via offers it. The glyph turns a full circle under the
/// finger and the phone ticks once: a retry almost always redraws the very
/// same screen — same error, same layout — so without that turn the traveller
/// has no way to tell the tap landed, and taps again.
///
/// The turn is a plain `rotationEffect` rather than a symbol effect so the
/// microinteraction is identical whatever glyph a caller passes in.
struct RetryButton: View {
    var label: LocalizedStringKey = "Réessayer"
    var systemImage: String = "arrow.clockwise"
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var turns = 0

    var body: some View {
        Button {
            turns += 1
            action()
        } label: {
            Label {
                Text(label)
            } icon: {
                Image(systemName: systemImage)
                    .rotationEffect(.degrees(Double(turns) * 360))
                    // Slightly underdamped: the arrow overshoots and settles,
                    // which reads as effort rather than as a spinner.
                    .animation(
                        reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.6),
                        value: turns,
                    )
            }
        }
        .haptic(Haptic.tap, on: turns)
    }
}

#Preview {
    VStack(spacing: 16) {
        RetryButton(action: {})
            .primaryAction()
        RetryButton(action: {})
            .secondaryAction()
        RetryButton(action: {})
            .iconAction(size: .small)
    }
    .padding()
}
