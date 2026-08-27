import SwiftUI

/// A quiet guidance beam around the whole app window.
///
/// The position annotation remains a compact map marker; the moving edge is a
/// state of the journey screen, just like the Apple Intelligence edge light is
/// a state of the natural-language screen.
struct JourneyScreenBeamView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Color.clear
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .borderBeam(
                border: .orange,
                beam: [
                    .clear,
                    .orange.opacity(0.45),
                    .yellow.opacity(0.85),
                    .orange.opacity(0.45),
                    .clear,
                ],
                beamBlur: 8,
                shape: ConcentricRectangle(corners: .concentric, isUniform: true),
                isEnabled: !reduceMotion
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

#Preview {
    Color(.systemBackground)
        .ignoresSafeArea()
        .overlay { JourneyScreenBeamView() }
}
