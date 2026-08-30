import SwiftUI

/// The amber diode used by live guidance in place of a station's white hole.
/// Its slow pulse echoes an onboard RER line display without becoming a rapid
/// flash; Reduce Motion leaves the same solid, high-contrast marker in place.
struct JourneyPositionIndicatorView: View {
    let status: JourneyStopProgress.Status
    let diameter: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { context in
            let pulse = pulseAmount(at: context.date)
            let pulseScale = CGFloat(pulse)

            ZStack {
                Circle()
                    .stroke(amber.opacity(0.68 - pulse * 0.36), lineWidth: 2)
                    .scaleEffect(1 + pulseScale * 0.38)

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [yellow, amber],
                            center: .topLeading,
                            startRadius: 0,
                            endRadius: diameter * 0.62
                        )
                    )
                    .overlay {
                        Circle()
                            .strokeBorder(Color.black.opacity(0.16), lineWidth: 1)
                    }
                    .scaleEffect(reduceMotion ? 1 : 0.94 + pulseScale * 0.06)
                    .shadow(
                        color: amber.opacity(reduceMotion ? 0.48 : 0.32 + pulse * 0.38),
                        radius: reduceMotion ? 3 : 2 + pulseScale * 4
                    )

                Circle()
                    .fill(.white.opacity(0.72))
                    .frame(width: diameter * 0.22, height: diameter * 0.22)
                    .offset(x: -diameter * 0.18, y: -diameter * 0.18)
            }
            .frame(width: diameter, height: diameter)
        }
        .accessibilityHidden(true)
    }

    private var amber: Color {
        switch status {
        case .current:
            Color(red: 1, green: 0.55, blue: 0.02)
        case .next:
            Color(red: 1, green: 0.62, blue: 0.03)
        }
    }

    private var yellow: Color {
        Color(red: 1, green: 0.88, blue: 0.22)
    }

    private func pulseAmount(at date: Date) -> Double {
        guard !reduceMotion else { return 1 }
        let period = 1.35
        let angle = date.timeIntervalSinceReferenceDate / period * 2 * Double.pi
        return (sin(angle) + 1) / 2
    }
}

#Preview("Diode de position") {
    HStack(spacing: 28) {
        JourneyPositionIndicatorView(status: .current, diameter: 19)
        JourneyPositionIndicatorView(status: .next, diameter: 19)
    }
    .padding(32)
    .background(Color(red: 0.89, green: 0.02, blue: 0.12))
}
