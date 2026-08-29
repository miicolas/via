import SwiftUI

/// One compact, noninteractive fact in the journey header.
struct JourneyHeaderMetricView: View {
    let value: String
    let systemImage: String
    let accessibilityLabel: String
    let accessibilityValue: String

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: systemImage)
                .font(.caption.weight(.semibold))

            Text(value)
                .font(.caption.weight(.semibold).monospacedDigit())
                .lineLimit(1)
        }
        .foregroundStyle(.secondary)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValue)
    }
}
