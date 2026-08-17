import SwiftUI

/// Compact row for a non-selected journey: segment chips on the left,
/// total duration pinned to the right.
struct JourneyAlternativeRow: View {
    let journey: Journey

    var body: some View {
        HStack(spacing: 12) {
            JourneySegmentStrip(journey: journey)

            Text(journey.totalDurationLabel)
                .font(.headline)
                .monospacedDigit()
                .fixedSize()
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    if let journey = JourneyResult.mapPreview.journeys.first {
        JourneyAlternativeRow(journey: journey)
            .padding()
    }
}
