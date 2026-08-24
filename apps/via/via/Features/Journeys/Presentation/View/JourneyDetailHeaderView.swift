import SwiftUI

/// The first glance at a journey: duration and timing quality. Screen actions
/// live in the native navigation toolbar owned by `JourneyDetailView`.
struct JourneyDetailHeaderView: View {
    let journey: Journey
    let source: JourneyResult.Source?

    var body: some View {
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
        }
    }

    private var timingLabel: String? {
        switch source {
        case .realtime: "Temps réel"
        case .theoretical: "Théorique"
        case nil: nil
        }
    }

    private var timingTint: Color {
        source == .realtime ? .green : .secondary
    }
}
