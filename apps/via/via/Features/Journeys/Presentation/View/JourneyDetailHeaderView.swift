import SwiftUI

/// The first glance at a journey: duration and timing quality. Screen actions
/// live in the native navigation toolbar owned by `JourneyDetailView`.
struct JourneyDetailHeaderView: View {
    let journey: Journey
    let source: JourneyResult.Source?

    var body: some View {
        // Estimating walks every geometry pair of every transit section; the
        // label and the spoken value are the same number, read once.
        let emission = journey.carbonEmission

        HStack(alignment: .firstTextBaseline, spacing: 10) {
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

            Spacer(minLength: 0)

            HStack(spacing: 5) {
                Image(systemName: "globe.europe.africa")
                    .font(.caption.weight(.semibold))

                Text(emission.displayText)
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(.secondary)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Émissions estimées de CO₂e")
            .accessibilityValue(emission.accessibilityText)
        }
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
