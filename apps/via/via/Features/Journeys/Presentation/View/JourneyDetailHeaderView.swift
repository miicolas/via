import SwiftUI

/// The first glance at a journey: duration and timing quality. Screen actions
/// live in the native navigation toolbar owned by `JourneyDetailView`.
struct JourneyDetailHeaderView: View {
    let journey: Journey
    let source: JourneyResult.Source?

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                durationAndTiming

                Spacer(minLength: 0)

                metrics
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    durationAndTiming
                }

                metrics
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }

    @ViewBuilder
    private var durationAndTiming: some View {
        Text(JourneyFormatting.duration(journey.durationSeconds))
            .font(.system(.largeTitle, design: .rounded, weight: .bold))
            .monospacedDigit()
            .contentTransition(.numericText())

        if let timingLabel {
            Text(timingLabel)
                .font(.caption.weight(.semibold))
                .foregroundStyle(timingTint)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(timingTint.opacity(0.14), in: .capsule)
        }
    }

    private var metrics: some View {
        // Estimating walks every geometry pair of every transit section; the
        // label and the spoken value are the same number, read once.
        let emission = journey.carbonEmission

        return HStack(spacing: 14) {
            if let fare = journey.fare {
                JourneyHeaderMetricView(
                    value: fare.displayText,
                    systemImage: "eurosign.circle",
                    accessibilityLabel: "Tarif plein indicatif",
                    accessibilityValue: fare.accessibilityText
                )
            }

            JourneyHeaderMetricView(
                value: emission.displayText,
                systemImage: "globe.europe.africa",
                accessibilityLabel: "Émissions estimées de CO₂e",
                accessibilityValue: emission.accessibilityText
            )
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var timingLabel: String? {
        if journey.status == .theoretical {
            return "Théorique"
        }
        switch source {
        case .realtime:
            return "Temps réel"
        case .theoretical:
            return "Théorique"
        case nil:
            return nil
        }
    }

    private var timingTint: Color {
        source == .realtime && journey.status != .theoretical ? .green : .secondary
    }
}
